require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(/test/.*), '/workflow.rb')

require 'fileutils'
require 'yaml'

# H-011 fix regression matrix (steps 3-4 of the fix plan).
#
# Covers BOTH edit modes of the scientific-record kinds through the PUBLIC
# interfaces (LLM::Agent#path_edit for the text mode, LLM::Agent#path_dispatch
# -> edit_fields for the field mode), with exact-content assertions.
#
# Record contract the expectations encode: a COMMITTED edit writes
# Research::PathKinds.serialize(kind, candidate) - the record
# implementation's own serialization of the parsed record - and snapshots the
# exact pre-edit body under history/.  So every successful-edit assertion
# compares the file with serialize(<expected parsed record>), and every
# history assertion compares with the exact pre-edit bytes.
#
# The folded fixture (physical line 0 is `---`):
#   0 ---  1 version  2 status  3 statement: '...  4 because...  5 final...'
#   6 scope:  7 population  8 limitations:  9 item1  10 item2
# The single-quoted scalar OPENS on line 3 and CLOSES on line 5, so any
# replacement covering line 5 must carry the closing quote, and any
# replacement of lines 3-4 must not close it early.
class TestH011RegressionMatrix < Test::Unit::TestCase
  FOLDED_STATEMENT =
    'The initial interpretation remains provisional because the shared ' \
    'response is also present in the control. The final qualification ' \
    'must remain intact.'

  def setup
    @tmpdir = File.join(Scout.tmp.test_h011_regression_matrix.find.to_s,
                        "h011-#{Process.pid}")
    FileUtils.mkdir_p(@tmpdir)
    @base = File.join(@tmpdir, 'checkout')
    FileUtils.mkdir_p(@base)
    @definitions = Research::PathKinds.definitions(base_dir: @base)
    @agent = LLM.agent
    @definitions.each { |kind, definition| @agent.register_path_kind(kind, definition) }
    @root = File.join(@base, 'var', 'records', 'hypothesis')
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  def dispatch(kind:, operation:, **rest)
    args = rest.each_with_object({}) { |(key, value), hash| hash[key.to_s] = value }
    @agent.path_dispatch(kind: kind, operation: operation, **args)
  end

  def register_hypothesis(extra = {})
    dispatch(kind: 'hypothesis', operation: 'register', 'path' => '.',
             'statement' => 'Original statement.',
             **extra)
  end

  def folded_body(version: 1, final_newline: true)
    text = <<~YAML
      ---
      version: #{version}
      status: proposed
      statement: 'The initial interpretation remains provisional
        because the shared response is also present in the control.
        The final qualification must remain intact.'
      scope:
        population: cohort A
      limitations:
      - No biological replicates
      - Small sample size
    YAML
    final_newline ? text : text.sub(/\n\z/, '')
  end

  def write_folded(final_newline: true)
    result = register_hypothesis
    File.write(result['file'], folded_body(version: result['version'],
                                           final_newline: final_newline))
    result
  end

  def record_file(id)
    File.join(@root, "#{id}.yaml")
  end

  def history_entries(id)
    Dir.glob(File.join(@root, 'history', "#{id}.v*.yaml"))
       .map { |f| File.basename(f) }.sort
  end

  def store_state(id)
    file = record_file(id)
    sidecar = File.join(@root, "#{id}.info.json")
    { 'file' => File.file?(file) ? File.read(file) : nil,
      'sidecar' => File.file?(sidecar) ? File.read(sidecar) : nil,
      'history' => Dir.glob(File.join(@root, 'history', '*')).sort }
  end

  def assert_store_untouched(id, before, note = '')
    after = store_state(id)
    assert_equal before['file'], after['file'],
      "record body must be byte-identical after a failed edit #{note}"
    assert_equal before['sidecar'], after['sidecar'],
      "sidecar must be byte-identical after a failed edit #{note}"
    assert_equal before['history'], after['history'],
      "history set must be unchanged (no orphan snapshot) #{note}"
  end

  def parse(path)
    YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
  end

  def serialize(record)
    Research::PathKinds.serialize('hypothesis', record)
  end

  def folded_record(version: 2, **overrides)
    { 'version' => version, 'statement' => FOLDED_STATEMENT,
      'scope' => { 'population' => 'cohort A' },
      'status' => 'proposed',
      'limitations' => ['No biological replicates', 'Small sample size'] }
      .merge(overrides)
  end

  def lines_span(old_lines, start, finish, replacement)
    (old_lines[0, start] + replacement.lines + old_lines[finish..]).join
  end

  # ==================================================================
  # TEXT MODE: intended edits on the folded scalar
  # ==================================================================

  def test_text_single_line_replacement_inside_folded_scalar
    result = write_folded
    before_body = File.read(result['file'])

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
             'replacement' => "  since the response is shared with the control.\n")

    expected = folded_record(
      'statement' => 'The initial interpretation remains provisional ' \
                     'since the response is shared with the control. ' \
                     'The final qualification must remain intact.'
    )
    assert_equal serialize(expected), File.read(record_file(result['path'])),
      'exactly the intended record is committed, through the serializer'
    assert_equal expected, parse(record_file(result['path']))
    assert_equal %w[H-001.v1.yaml], history_entries(result['path'])
    assert_equal before_body,
                 File.read(File.join(@root, 'history', 'H-001.v1.yaml')),
      'the snapshot holds the exact pre-edit body, folded form included'
  end

  def test_text_multi_line_replacement_of_whole_scalar
    result = write_folded

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 3, 'end' => 6 },
             'replacement' => "statement: 'A sharper, single-line formulation.'\n")

    expected = folded_record('statement' => 'A sharper, single-line formulation.')
    assert_equal serialize(expected), File.read(record_file(result['path']))
    assert_equal expected, parse(record_file(result['path']))
  end

  def test_text_last_continuation_line_replacement
    result = write_folded

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 5, 'end' => 6 },
             'replacement' => "  The final qualification stands.'\n")

    expected = folded_record(
      'statement' => 'The initial interpretation remains provisional ' \
                     'because the shared response is also present in the ' \
                     'control. The final qualification stands.'
    )
    assert_equal serialize(expected), File.read(record_file(result['path']))
    assert_equal expected, parse(record_file(result['path']))
  end

  def test_text_span_across_scalar_start
    result = write_folded

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 2, 'end' => 6 },
             'replacement' => "status: proposed\n" \
                              "statement: 'A rewritten provisional reading\n" \
                              "  with a new continuation line.'\n")

    expected = folded_record(
      'statement' => 'A rewritten provisional reading with a new continuation line.'
    )
    assert_equal serialize(expected), File.read(record_file(result['path']))
    assert_equal expected, parse(record_file(result['path']))
  end

  def test_text_edit_adjacent_to_other_fields
    result = write_folded

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 7, 'end' => 8 },
             'replacement' => "  population: cohort B\n")

    expected = folded_record('scope' => { 'population' => 'cohort B' })
    assert_equal serialize(expected), File.read(record_file(result['path']))
    assert_equal expected, parse(record_file(result['path']))
  end

  def test_text_scalar_at_eof_with_final_newline
    result = register_hypothesis
    body = <<~YAML
      ---
      version: #{result['version']}
      status: proposed
      statement: 'The initial interpretation remains provisional
        because the shared response is also present in the control.'
    YAML
    File.write(result['file'], body)

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
             'replacement' => "  because the response is shared.'\n")

    expected = { 'version' => 2, 'status' => 'proposed',
                 'statement' => 'The initial interpretation remains ' \
                                'provisional because the response is shared.' }
    assert_equal serialize(expected), File.read(record_file(result['path'])),
      'the EOF span keeps the final newline the document had'
    assert_equal expected, parse(record_file(result['path']))
  end

  def test_text_eof_span_without_final_newline_allows_unterminated_replacement
    result = register_hypothesis
    body = <<~YAML.sub(/\n\z/, '')
      ---
      version: #{result['version']}
      status: proposed
      statement: 'The initial interpretation remains provisional
        because the shared response is also present in the control.'
    YAML
    File.write(result['file'], body)

    # G2 explicitly exempts an EOF span of a document without a final
    # newline: reproducing an unterminated last line is legitimate there.
    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
             'replacement' => "  because the response is shared.'")

    expected = { 'version' => 2, 'status' => 'proposed',
                 'statement' => 'The initial interpretation remains ' \
                                'provisional because the response is shared.' }
    assert_equal serialize(expected), File.read(record_file(result['path'])),
      'the guard accepts the EOF-without-final-newline case and the commit ' \
      'path writes the canonical serialization'
    assert_equal expected, parse(record_file(result['path']))
  end

  def test_text_eof_span_without_final_newline_strips_terminator
    result = register_hypothesis
    body = <<~YAML.sub(/\n\z/, '')
      ---
      version: #{result['version']}
      status: proposed
      statement: 'The initial interpretation remains provisional
        because the shared response is also present in the control.'
    YAML
    File.write(result['file'], body)

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
             'replacement' => "  because the response is shared.'\n")

    expected = { 'version' => 2, 'status' => 'proposed',
                 'statement' => 'The initial interpretation remains ' \
                                'provisional because the response is shared.' }
    assert_equal serialize(expected), File.read(record_file(result['path'])),
      'the same record results when the replacement carries the terminator ' \
      'the document lacks; the engine splice normalizes it away'
    assert_equal expected, parse(record_file(result['path']))
  end

  def test_text_empty_replacement_deletes_one_list_item
    result = write_folded

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 9, 'end' => 10 },
             'replacement' => '')

    expected = folded_record('limitations' => ['Small sample size'])
    assert_equal serialize(expected), File.read(record_file(result['path'])),
      'the empty replacement deletes the selected line and nothing else'
    assert_equal expected, parse(record_file(result['path']))
  end

  def test_text_zero_span_insertion
    result = write_folded

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 7, 'end' => 7 },
             'replacement' => "  cohort: B\n")

    expected = folded_record('scope' => { 'cohort' => 'B',
                                          'population' => 'cohort A' })
    assert_equal serialize(expected), File.read(record_file(result['path']))
    assert_equal expected, parse(record_file(result['path']))
  end

  def test_text_zero_range_chars_insertion
    result = write_folded
    file = record_file(result['path'])
    body = File.read(file)
    point = body.index('cohort A')

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'chars', 'start' => point, 'end' => point },
             'replacement' => 'historical ')

    expected = folded_record('scope' => { 'population' => 'historical cohort A' })
    assert_equal serialize(expected), File.read(file)
    assert_equal expected, parse(file)
  end

  def test_text_successive_edits_each_see_prior_result
    result = write_folded
    file = record_file(result['path'])
    folded = File.read(file)

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
             'replacement' => "  since the response is shared.\n")
    v2_body = File.read(file)

    # The second edit reads the CURRENT (serialized) body, not the folded
    # original: it rewrites one list item in the body the first edit wrote.
    v2_lines = v2_body.lines
    item = v2_lines.index { |line| line.start_with?('- No biological replicates') }
    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => item, 'end' => item + 1 },
             'replacement' => "- No biological replicates (six independent runs)\n")

    expected = folded_record(
      'version' => 3,
      'statement' => 'The initial interpretation remains provisional since ' \
                     'the response is shared. The final qualification ' \
                     'must remain intact.',
      'limitations' => ['No biological replicates (six independent runs)',
                        'Small sample size']
    )
    assert_equal serialize(expected), File.read(file),
      'the second edit applies to the FIRST edit result'
    assert_equal expected, parse(file)
    assert_equal %w[H-001.v1.yaml H-001.v2.yaml], history_entries(result['path'])
    assert_equal folded, File.read(File.join(@root, 'history', 'H-001.v1.yaml'))
    assert_equal v2_body, File.read(File.join(@root, 'history', 'H-001.v2.yaml')),
      'each snapshot holds the exact body it superseded'
  end

  def test_text_post_edit_read_matches_file_and_history_is_readable
    result = write_folded
    folded = File.read(result['file'])

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
             'replacement' => "  since the response is shared.\n")

    read = dispatch(kind: 'hypothesis', operation: 'read', path: result['path'])
    assert_equal File.read(record_file(result['path'])), read['content'],
      'the public read returns the committed body verbatim'
    snapshot = File.join(@root, 'history', 'H-001.v1.yaml')
    assert_equal folded, File.read(snapshot)
    assert_equal 1, parse(snapshot)['version'],
      'the history version parses as the version it superseded'
  end

  # ==================================================================
  # TEXT MODE: guards and failures must not mutate anything
  # ==================================================================

  def test_text_replacement_repasting_head_line_is_rejected_untouched
    result = write_folded
    before = store_state(result['path'])
    body = folded_body.lines

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
               'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
               'replacement' => body[3, 2].join)
    end
    assert_match(/duplication/, error.message)
    assert_store_untouched(result['path'], before, '(guard: head re-paste)')
  end

  def test_text_replacement_repasting_tail_line_is_rejected_untouched
    result = write_folded
    before = store_state(result['path'])
    body = folded_body.lines

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
               'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
               'replacement' => body[4, 2].join)
    end
    assert_match(/duplication/, error.message)
    assert_store_untouched(result['path'], before, '(guard: tail re-paste)')
  end

  def test_text_unterminated_fragment_inside_document_is_rejected_untouched
    result = write_folded
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
               'selector' => { 'type' => 'lines', 'start' => 9, 'end' => 10 },
               'replacement' => '- No biological replicates (partial repair')
    end
    assert_match(/newline-terminated/, error.message)
    assert_store_untouched(result['path'], before, '(guard: fragment)')
  end

  def test_text_out_of_range_selector_rejected_untouched
    result = write_folded
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
               'selector' => { 'type' => 'lines', 'start' => 99, 'end' => 99 },
               'replacement' => "x\n")
    end
    assert_match(/beyond the last index/, error.message)
    assert_store_untouched(result['path'], before, '(out of range)')
  end

  def test_text_stale_version_rejected_untouched
    result = write_folded

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
             'replacement' => "  since the response is shared.\n")
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
               'selector' => { 'type' => 'lines', 'start' => 1, 'end' => 2 },
               'replacement' => "version: 1\n")
    end
    assert_match(/stale edit/, error.message)
    assert_store_untouched(result['path'], before, '(stale)')
    assert_equal 2, parse(record_file(result['path']))['version'],
      'a stale edit must not advance the version'
  end

  def test_text_schema_validation_failure_rejected_untouched
    result = write_folded
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
               'selector' => { 'type' => 'lines', 'start' => 8, 'end' => 11 },
               'replacement' => "limitations: not-a-list\n")
    end
    assert_match(/edit rejected/, error.message)
    assert_match(/limitations/, error.message)
    assert_store_untouched(result['path'], before, '(schema failure)')
  end

  def test_text_unknown_key_insertion_rejected_untouched
    result = write_folded
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
               'selector' => { 'type' => 'lines', 'start' => 1, 'end' => 1 },
               'replacement' => "extra_key: 1\n")
    end
    assert_match(/unknown top-level field/, error.message)
    assert_store_untouched(result['path'], before, '(unknown key)')
  end

  def test_text_invalid_status_transition_rejected_untouched
    result = write_folded
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
               'selector' => { 'type' => 'lines', 'start' => 2, 'end' => 3 },
               'replacement' => "status: current\n")
    end
    assert_match(/invalid status transition/, error.message)
    assert_store_untouched(result['path'], before, '(invalid transition)')
  end

  # ==================================================================
  # FIELD MODE: edit_fields through the public custom operation
  # ==================================================================

  def test_edit_fields_installs_one_public_tool_with_identical_contract
    tools = @agent.other_options[:tools]
    assert tools.key?('edit_fields'),
      'the three kinds must install exactly one edit_fields tool'
    assert_equal 1, tools.keys.count { |n| n == 'edit_fields' }
    schema = tools['edit_fields'].last['function']['parameters']
    assert_equal %w[fields kind path version], schema['required'].sort
    types = %w[version fields].map { |k| schema['properties'][k]['type'] }.sort
    assert_equal %w[integer object], types
    assert_equal true, schema['properties']['fields']['additionalProperties'],
      'the fields mapping accepts arbitrary field names (validated later)'
  end

  def test_edit_fields_assigns_statement_and_bumps_version_exactly
    result = register_hypothesis('title' => 'T', 'scope' => { 'a' => 1 })
    file = record_file(result['path'])
    register_body = File.read(file)

    edited = dispatch(kind: 'hypothesis', operation: 'edit_fields',
                      path: result['path'], 'version' => 1,
                      'fields' => { 'statement' =>
                                    "A two-line statement\nwith a newline." })

    expected = { 'version' => 2,
                 'statement' => "A two-line statement\nwith a newline.",
                 'title' => 'T', 'scope' => { 'a' => 1 },
                 'status' => 'proposed' }
    assert_equal serialize(expected), File.read(file),
      'the committed body is exactly the record implementation serialization'
    assert_equal expected, parse(file)
    assert_equal 2, edited['version']
    assert_equal true, edited['changed']
    assert_equal %w[H-001.v1.yaml], history_entries(result['path'])
    assert_equal register_body,
                 File.read(File.join(@root, 'history', 'H-001.v1.yaml')),
      'the snapshot holds the exact pre-edit register body'
  end

  def test_edit_fields_multiple_fields_and_status_transition_in_one_call
    result = register_hypothesis('title' => 'T')
    file = record_file(result['path'])

    dispatch(kind: 'hypothesis', operation: 'edit_fields',
             path: result['path'], 'version' => 1,
             'fields' => { 'title' => 'Sharper title',
                           'limitations' => ['No replicates'],
                           'status' => 'under_test' })

    expected = { 'version' => 2, 'statement' => 'Original statement.',
                 'title' => 'Sharper title', 'status' => 'under_test',
                 'limitations' => ['No replicates'] }
    assert_equal serialize(expected), File.read(file)
    assert_equal expected, parse(file)
  end

  def test_edit_fields_null_removes_optional_field
    result = register_hypothesis('title' => 'To be removed')
    file = record_file(result['path'])

    dispatch(kind: 'hypothesis', operation: 'edit_fields',
             path: result['path'], 'version' => 1,
             'fields' => { 'title' => nil })

    expected = { 'version' => 2, 'statement' => 'Original statement.',
                 'status' => 'proposed' }
    assert_equal serialize(expected), File.read(file),
      'a null assignment removes the field and the serializer omits it'
    assert_equal expected, parse(file)
  end

  def test_edit_fields_preserves_every_unmentioned_field_exactly
    result = register_hypothesis(
      'title' => 'Keep me',
      'scope' => { 'population' => 'cohort A', 'n' => 3 },
      'limitations' => ['No biological replicates'],
      'predictions' => ['Effect reverses'],
      'test_ideas' => ['Crossover']
    )
    file = record_file(result['path'])
    before = parse(file)

    dispatch(kind: 'hypothesis', operation: 'edit_fields',
             path: result['path'], 'version' => 1,
             'fields' => { 'statement' => 'Rewritten statement.' })

    after = parse(file)
    %w[title scope limitations predictions test_ideas status].each do |field|
      assert_equal before[field], after[field],
        "field #{field} must survive a field edit that does not name it"
    end
    assert_equal 'Rewritten statement.', after['statement']
    assert_equal 2, after['version']
  end

  def test_edit_fields_does_not_silently_drop_keys_the_schema_rejects
    # A body carrying a key outside the kind schema (hand-written, as the
    # H-011 incident files were) must NOT be laundered by a field edit: the
    # key is carried into the candidate, validation rejects, nothing moves.
    result = register_hypothesis
    file = record_file(result['path'])
    body = File.read(file)
    File.write(file, body.sub(/^status:/, "custom_note: kept on disk\nstatus:"))
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit_fields',
               path: result['path'], 'version' => 1,
               'fields' => { 'statement' => 'New statement.' })
    end
    assert_match(/unknown top-level field/, error.message)
    assert_store_untouched(result['path'], before,
                           '(unmodeled key preserved, not dropped)')
    assert parse(file).key?('custom_note'),
      'the unmodeled key must still be on disk after the rejection'
  end

  def test_edit_fields_stale_version_rejected_untouched
    result = register_hypothesis
    dispatch(kind: 'hypothesis', operation: 'edit_fields',
             path: result['path'], 'version' => 1,
             'fields' => { 'statement' => 'First change.' })
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit_fields',
               path: result['path'], 'version' => 1,
               'fields' => { 'statement' => 'Second change.' })
    end
    assert_match(/stale edit of H-001/, error.message)
    assert_store_untouched(result['path'], before, '(field-mode stale)')
  end

  def test_edit_fields_schema_failure_rejected_untouched
    result = register_hypothesis
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit_fields',
               path: result['path'], 'version' => 1,
               'fields' => { 'limitations' => 'not-a-list' })
    end
    assert_match(/edit rejected for H-001/, error.message)
    assert_match(/limitations/, error.message)
    assert_store_untouched(result['path'], before, '(field-mode schema failure)')
  end

  def test_edit_fields_invalid_status_transition_rejected_untouched
    result = register_hypothesis
    dispatch(kind: 'hypothesis', operation: 'edit_fields',
             path: result['path'], 'version' => 1,
             'fields' => { 'status' => 'superseded' })
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit_fields',
               path: result['path'], 'version' => 2,
               'fields' => { 'status' => 'under_test' })
    end
    assert_match(/invalid status transition/, error.message)
    assert_store_untouched(result['path'], before,
                           '(field-mode invalid transition)')
  end

  def test_edit_fields_rejects_version_and_unknown_fields
    result = register_hypothesis
    before = store_state(result['path'])

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit_fields',
               path: result['path'], 'version' => 1,
               'fields' => { 'version' => 99 })
    end
    assert_match(/system-managed field/, error.message)

    error = assert_raise(ParameterException) do
      dispatch(kind: 'hypothesis', operation: 'edit_fields',
               path: result['path'], 'version' => 1,
               'fields' => { 'no_such_field' => 1 })
    end
    assert_match(/unknown or system-managed field/, error.message)
    assert_store_untouched(result['path'], before, '(bad field names)')
  end

  def test_edit_fields_noop_returns_changed_false_and_touches_nothing
    result = register_hypothesis('title' => 'T')
    before = store_state(result['path'])

    edited = dispatch(kind: 'hypothesis', operation: 'edit_fields',
                      path: result['path'], 'version' => 1,
                      'fields' => { 'statement' => 'Original statement.' })

    assert_equal false, edited['changed']
    assert_equal 1, edited['version']
    assert_store_untouched(result['path'], before, '(field-mode no-op)')
  end

  def test_edit_fields_successive_edits_each_see_prior_result
    result = register_hypothesis
    file = record_file(result['path'])

    dispatch(kind: 'hypothesis', operation: 'edit_fields',
             path: result['path'], 'version' => 1,
             'fields' => { 'statement' => 'First.' })
    dispatch(kind: 'hypothesis', operation: 'edit_fields',
             path: result['path'], 'version' => 2,
             'fields' => { 'title' => 'Second.' })

    expected = { 'version' => 3, 'statement' => 'First.',
                 'title' => 'Second.', 'status' => 'proposed' }
    assert_equal serialize(expected), File.read(file)
    assert_equal expected, parse(file)
    assert_equal %w[H-001.v1.yaml H-001.v2.yaml], history_entries(result['path'])
  end

  def test_edit_fields_after_text_edit_uses_the_new_version
    result = write_folded
    file = record_file(result['path'])

    dispatch(kind: 'hypothesis', operation: 'edit', path: result['path'],
             'selector' => { 'type' => 'lines', 'start' => 4, 'end' => 5 },
             'replacement' => "  since the response is shared.\n")

    dispatch(kind: 'hypothesis', operation: 'edit_fields',
             path: result['path'], 'version' => 2,
             'fields' => { 'title' => 'Set by field mode.' })

    expected = folded_record(
      'version' => 3,
      'statement' => 'The initial interpretation remains provisional since ' \
                     'the response is shared. The final qualification must ' \
                     'remain intact.',
      'title' => 'Set by field mode.'
    )
    assert_equal serialize(expected), File.read(file)
    assert_equal expected, parse(file),
      'both modes share one version sequence and one commit path'
  end
end
