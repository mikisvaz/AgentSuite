require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(/test/.*), '/workflow.rb')

require 'fileutils'

# H-011 regression (path-edit corruption cluster, step 2 of the fix plan).
#
# Incident: `path_edit` with a `lines` selector on a multi-line single-quoted
# YAML scalar duplicated preceding lines in Hypothesis record H-011 across
# v5-v12; sloppy repairs added further duplication (v12->v13 appended
# `demonstration)` onto an existing list item; v13->v14 cleaned a
# `the migration manifest. the migration manifest.` duplication).
#
# These tests drive the PUBLIC engine operation (LLM::Agent#path_edit, the
# same entry scout-ai uses for the installed path tools) against the REAL
# hypothesis-kind definition, so the edit override, the record validator and
# the serializer are all in the loop, exactly as in the incident.
#
# Step-2 attribution evidence (fresh-process probes, real override):
#   - a `lines` replacement that re-pastes preceding physical lines of the
#     folded single-quoted statement scalar is ACCEPTED and COMMITTED: Psych
#     folds the duplicated fragments into ONE statement value with the text
#     concatenated, so the corruption survives validation (the v5-v12 shape);
#   - a `lines` replacement that is not newline-terminated inside a list is
#     ACCEPTED and COMMITTED with the fragment concatenated onto the NEXT
#     physical line (the v12->v13 `demonstration)` shape).
class TestH011LinesEdit < Test::Unit::TestCase
  def setup
    @tmpdir = File.join(Scout.tmp.test_h011_lines_edit.find.to_s, "h011-#{Process.pid}")
    FileUtils.mkdir_p(@tmpdir)
    @base = File.join(@tmpdir, 'checkout')
    FileUtils.mkdir_p(@base)
    @definitions = Research::PathKinds.definitions(base_dir: @base)
    @agent = LLM.agent
    @definitions.each { |kind, definition| @agent.register_path_kind(kind, definition) }
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  # A hypothesis record whose statement is a FOLDED single-quoted scalar, the
  # exact shape the incident corrupted.  Physical line 0 is `---`.
  def register_folded_record
    statement = "The initial interpretation remains provisional\n" \
                "because the shared response is also present in the control.\n" \
                "The final qualification must remain intact."
    result = @agent.path_dispatch(
      kind: 'hypothesis', operation: 'register',
      'path' => '.',
      'statement' => statement,
      'scope' => { 'population' => 'cohort A' },
      'limitations' => ['No biological replicates']
    )
    # Rewrite the body into the folded single-quoted scalar form the incident
    # had (the serializer emits a plain flow style; the incident file used
    # the quoted folded form), keeping the engine-issued version.
    body = File.read(result['file'])
    folded = <<~YAML
      ---
      version: #{result['version']}
      status: proposed
      statement: 'The initial interpretation remains provisional
        because the shared response is also present in the control.
        The final qualification must remain intact.'
      scope:
        population: cohort A
      limitations:
      - No biological replicates
    YAML
    File.write(result['file'], folded)
    result
  end

  def test_lines_edit_that_repastes_preceding_lines_is_rejected
    result = register_folded_record
    path = result['path']
    body_lines = File.read(result['file']).lines
    stmt_idx = body_lines.index { |l| l.start_with?("statement:") }

    # The corruption-shaped edit the incident agent performed: replace the
    # statement VALUE line with the statement line plus its own first
    # continuation line verbatim (re-pasting what it had just read).
    replacement = body_lines[stmt_idx, 2].join

    error = assert_raise(ParameterException) do
      @agent.path_edit(
        'kind' => 'hypothesis', 'path' => path,
        'selector' => { 'type' => 'lines', 'start' => stmt_idx, 'end' => stmt_idx + 1 },
        'replacement' => replacement
      )
    end

    assert_match(/duplication/i, error.message,
      "the record layer must refuse a lines replacement that duplicates " \
      "preceding physical lines of the folded scalar; got: #{error.message}")
  end

  def test_lines_edit_intended_replacement_preserves_scalar_value
    result = register_folded_record
    path = result['path']
    body_lines = File.read(result['file']).lines
    stmt_idx = body_lines.index { |l| l.start_with?("statement:") }

    # The INTENDED edit: replace the statement VALUE line with its own text.
    @agent.path_edit(
      'kind' => 'hypothesis', 'path' => path,
      'selector' => { 'type' => 'lines', 'start' => stmt_idx, 'end' => stmt_idx + 1 },
      'replacement' => body_lines[stmt_idx]
    )

    require 'yaml'
    parsed = YAML.safe_load(File.read(result['file']),
                            permitted_classes: [], aliases: false)
    assert_equal "The initial interpretation remains provisional " \
                 "because the shared response is also present in the " \
                 "control. The final qualification must remain intact.",
                 parsed['statement'],
      "the intended edit must leave the folded scalar VALUE byte-identical"
  end

  def test_non_newline_terminated_replacement_inside_list_is_rejected
    result = register_folded_record
    path = result['path']
    body_lines = File.read(result['file']).lines
    item_idx = body_lines.index { |l| l.start_with?('- ') }

    # The v12->v13 shape: a fragment that is not newline-terminated gets
    # concatenated onto the following physical line by the generic splice and
    # committed by the record layer.
    error = assert_raise(ParameterException) do
      @agent.path_edit(
        'kind' => 'hypothesis', 'path' => path,
        'selector' => { 'type' => 'lines', 'start' => item_idx, 'end' => item_idx + 1 },
        'replacement' => '- No biological replicates (partial repair'
      )
    end

    assert_match(/newline|terminated|trailing/i, error.message,
      "the record layer must refuse a lines replacement that is not " \
      "newline-terminated inside a block sequence; got: #{error.message}")
  end
end
