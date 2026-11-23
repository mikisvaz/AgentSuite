require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'scout'
require 'tmpdir'
require 'fileutils'

# Scout resolves job paths from Workflow.directory, shared with every other
# process on the host.  Two runs that hand a task the same non-default inputs
# get the same digest and silently reuse each other's artifacts: a job whose
# result was already persisted is reloaded from disk (JSON: string keys,
# possibly re-encoded text) instead of executed, which changes what `.run`
# returns for identical inputs.  Point the jobs root at a fresh directory per
# process BEFORE the workflow loads, so every task directory derives from it
# and the suite observes only its own executions.
JOBS_ROOT = Dir.mktmpdir('workspace-tsv-jobs')
at_exit { FileUtils.remove_entry(JOBS_ROOT) }
Workflow.directory = Path.setup(JOBS_ROOT)

require File.expand_path('../../../workflow', __dir__)

class TestWorkspaceTSV < Test::Unit::TestCase
  def with_tsv(content, name = 'source.tsv')
    Dir.mktmpdir('workspace-tsv') do |dir|
      path = File.join(dir, name)
      File.binwrite(path, content)
      yield path, dir
    end
  end

  def job(name, **inputs)
    Workspace.job(name, nil, inputs)
  end

  def read_job(name, file, **inputs)
    job(name, file: file, **inputs)
  end

  def tsv_text(type: 'double', fields: "#ID\tGene\tScore", rows: "A\tTP53|BRCA1\t1|2\n")
    "#: :type=:#{type}\n#{fields}\n#{rows}"
  end

  # scout-ai's LLM.call_workflow drops empty-string parameter values
  # ("Some models use '' for optional parameters") BEFORE building the job,
  # so the harness never runs a job carrying header_hash: ''. The job built
  # from the raw inputs is therefore a different input vector (a different
  # digest) even when the persisted content is identical. Predicting the
  # harness path must use the same filtered inputs; equality with a job
  # built from raw inputs is NOT contractual.
  def run_with_harness_return_path(name, **inputs)
    effective = inputs.reject { |_key, value| value == '' }
    expected = job(name, **effective).path.to_s
    path = LLM.call_workflow(Workspace, name, inputs.merge(return_path: true)).to_s
    assert(File.file?(path), 'harness return_path points to the persisted job result')
    assert_equal File.expand_path(expected), File.expand_path(path)
    path
  end

  def inputs_for(name)
    Workspace.tasks[name].inputs.map { |input| input.respond_to?(:name) ? input.name : input }
  end

  def error_message(job)
    job.run
    nil
  rescue ParameterException => e
    e.message
  end

  # ------------------------------------------------------------------
  # Task surface
  # ------------------------------------------------------------------

  def test_task_surface_is_consolidated_and_harness_owns_return_path
    names = Workspace.tasks.keys.grep(/\Atsv_/).map(&:to_sym).sort
    assert_equal %i[tsv_attach tsv_edit tsv_info tsv_merge tsv_query tsv_read tsv_set_metadata tsv_sort tsv_translate], names
    names.each do |name|
      inputs = inputs_for(name)
      assert_not_include inputs, :return_path, "#{name} must not declare the harness option as a task input"
    end
    %i[tsv_query tsv_edit tsv_merge tsv_attach tsv_translate].each do |name|
      inputs = inputs_for(name)
      assert_empty(%i[sep sep2 header_hash] & inputs, "#{name} consumes prepared Scout TSV")
    end
    tool = LLM.task_tool_definition(Workspace, :tsv_read)
    assert_include tool[:parameters][:properties].keys.map(&:to_sym), :return_path
    assert_equal 'boolean', tool[:parameters][:properties][:return_path][:type].to_s
    assert_match /return the path/, tool[:parameters][:properties][:return_path][:description].to_s,
                 'the tool surface must document the harness option'
  end

  def test_harness_option_is_extracted_not_an_input_on_persistent_result_workflow_task
    with_tsv("#: :type=:double\n#ID\tScore\nA\t1\n") do |file, _dir|
      # Behavioral: the option is not a task input, is not forwarded to the
      # task body, and still controls whether the harness answers with the
      # persisted job path instead of the task's text product.
      refute_includes inputs_for(:tsv_read), :return_path

      job = Workspace.job(:tsv_read, nil, file: file)
      returned = LLM.call_workflow(Workspace, :tsv_read, {file: file})
      assert_equal job.path.to_s, returned.path.to_s,
                   'without return_path the harness hands back the job itself'
      assert_equal job.run.to_s, returned.run.to_s, 'the job product is the rendered Scout TSV text'
      answer = returned.run.to_s
      assert_match(/\A#:/, answer)

      path = LLM.call_workflow(Workspace, :tsv_read, {file: file, return_path: true}).to_s
      assert(File.file?(path), 'return_path yields the persisted job result path')
      assert_equal job.run.to_s, File.binread(path)
    end
  end

  # ------------------------------------------------------------------
  # tsv_info: side-effect free inspection
  # ------------------------------------------------------------------

  def test_info_reports_shape_and_entity_format_candidates
    with_tsv("#: :type=:double\n#ID\tGene\tScore\nA\tTP53|BRCA1\t1|2\n") do |file, _dir|
      result = read_job(:tsv_info, file).run
      assert_equal 'ID', result[:key_field]
      assert_equal %w[Gene Score], result[:fields]
      assert_equal :double, result[:type]
      assert_equal 1, result[:source_rows]
      assert_equal 1, result[:unique_keys]
      assert_equal 1, result[:physical_input_records]
      assert_equal [], result[:entity_field_candidates]
    end
  end

  def test_info_reports_materialized_keys_separately_from_physical_input_records
    with_tsv("#: :type=:double\n#ID\tScore\nA\tfirst\nA\tlast\nB\t5\n") do |file, _dir|
      result = read_job(:tsv_info, file).run
      assert_equal 2, result[:source_rows], 'materialized keys collapse duplicates'
      assert_equal 2, result[:unique_keys]
      assert_equal 3, result[:physical_input_records], 'three physical records were read'
    end
  end

  def test_info_is_side_effect_free_and_does_not_persist_metadata_options
    with_tsv("#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n") do |file, dir|
      identifiers = File.join(dir, 'ids.tsv')
      File.write(identifiers, "#ID\tSample\nA\tS1\n")
      before = File.binread(file)
      result = read_job(:tsv_info, file, new_key_field: 'Sample', rename_fields: %w[Symbol Rank],
                        cast: 'to_i', new_type: 'double', namespace: 'study',
                        identifiers: identifiers).run
      assert_equal 'ID', result[:key_field], 'inspection never renames'
      assert_equal %w[Gene Score], result[:fields]
      assert_equal :list, result[:type]
      assert_equal before, File.binread(file), 'tsv_info must not rewrite its source'
      reopened = TSV.open(file, persist: false)
      assert_equal 'ID', reopened.key_field
      assert_equal %w[Gene Score], reopened.fields
    end
  end

  def test_info_with_projection_reports_the_projected_view_without_persisting_it
    with_tsv("#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n") do |file, _dir|
      before = File.binread(file)
      result = read_job(:tsv_info, file, fields: ['Score']).run
      assert_equal %w[Score], result[:fields]
      assert_equal before, File.binread(file), 'projection is interpreted, not persisted'
      assert_equal %w[Gene Score], TSV.open(file, persist: false).fields
    end
  end

  def test_info_resolves_symlinks_for_reads_but_mutations_reject_them
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n", 'target.tsv') do |target, dir|
      link = File.join(dir, 'source-link.tsv')
      File.symlink(target, link)
      before = File.binread(target)

      info = read_job(:tsv_info, link).run
      assert_equal 1, info[:unique_keys], 'reads resolve a symlink inside the granted root'

      assert_raise(ParameterException) { read_job(:tsv_edit, link, key: 'A', field: 'Score', value: '7').run }
      assert_raise(ParameterException) { read_job(:tsv_set_metadata, link, namespace: 'x').run }
      assert_equal before, File.binread(target), 'no mutation path accepts a symlink'
    end
  end

  def test_merge_false_keeps_last_duplicate_key_row_in_read_and_info
    with_tsv("#: :type=:double\n#ID\tScore\nA\tfirst\nA\tlast\n") do |file, _dir|
      read = read_job(:tsv_read, file, merge: 'false').run
      table = TSV.open(StringIO.new(read), persist: false)
      assert_equal ['A'], table.keys
      assert_equal [%w[last]], table['A']

      info = read_job(:tsv_info, file, merge: 'false').run
      assert_equal 1, info[:source_rows]
      assert_equal 1, info[:unique_keys]
      assert_equal 2, info[:physical_input_records]
      assert_equal [%w[first last]], TSV.open(file, persist: false)['A'],
                   'the source keeps the default merge; merge:false is an interpretation for this call only'
    end
  end

  # ------------------------------------------------------------------
  # Read policy: mutations must be authorized even when the OS allows them
  # ------------------------------------------------------------------

  def with_read_grant(path)
    LLM::Sandbox.allow_read_path(path)
    begin
      yield
    ensure
      Thread.current['allowed_read_paths'] = (Thread.current['allowed_read_paths'] || []).reject { |p| p == path }
    end
  end

  # A grant directory outside every configured grant, used to prove that
  # mutation authorization does not fall back to OS writability.
  ISOLATED_ROOT = '/var/tmp/workspace-tsv-isolated'

  def test_ungranted_writable_file_can_be_read_but_not_mutated
    FileUtils.mkdir_p(ISOLATED_ROOT)
    Dir.mktmpdir('grant', ISOLATED_ROOT) do |dir|
      # Unique content: Scout digests path inputs by content, so an identical
      # table elsewhere in this suite would collide on the job digest and hand
      # this test a cached step bound to another test's path.
      file = File.join(dir, 'rw-grant-probe.tsv')
      File.binwrite(file, "#: :type=:single\n#ID\tScore\nGRANT1\t42\n")
      File.chmod(0o666, file)
      File.chmod(0o777, dir)
      before = File.binread(file)

      with_read_grant(file) do
        assert_equal 1, read_job(:tsv_info, file).run[:unique_keys],
                     'read of an OS-writable, read-granted file works'

        # The read grant stays ACTIVE through both mutation attempts: the file
        # is readable (inspection succeeds above) yet still not writable
        # authorization-wise. This proves write authorization refuses on its
        # own, not because the read was denied first (regression: the grant
        # used to be dropped before the mutations, so both jobs failed at
        # normalize(file, :read) — a read denial).
        assert_includes (Thread.current['allowed_read_paths'] || []), file
        assert_raise(SandboxAccessViolation) { read_job(:tsv_set_metadata, file, namespace: 'grant-probe').run }
        assert_raise(SandboxAccessViolation) { read_job(:tsv_edit, file, key: 'GRANT1', field: 'Score', value: '7').run }
        assert_equal before, File.binread(file), 'the mutation was refused before opening for rewrite'
      end
    end
  end

  # ------------------------------------------------------------------
  # tsv_set_metadata: the explicit mutation operation
  # ------------------------------------------------------------------

  def test_set_metadata_persists_renamed_fields_namespace_and_identifier_path
    with_tsv("#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n") do |file, _dir|
      identifiers = File.join(File.dirname(file), 'ids.tsv')
      result = read_job(:tsv_set_metadata, file, new_key_field: 'Sample', rename_fields: %w[Symbol Rank],
                         namespace: 'test', identifiers: identifiers).run
      assert_equal 'Sample', result[:key_field]
      assert_equal %w[Symbol Rank], result[:fields]
      assert_equal 'test', result[:namespace]
      assert_equal identifiers, result[:identifiers]
      reopened = TSV.open(file, persist: false)
      assert_equal 'test', reopened.namespace
      assert_equal identifiers, reopened.identifiers
      assert_equal 'Sample', reopened.key_field
      assert_equal %w[Symbol Rank], reopened.fields
      assert_equal 'list', reopened.type.to_s
      assert_equal ['TP53', '7'], reopened['A']
    end
  end

  def test_set_metadata_persists_cast_type_and_combined_updates
    with_tsv("#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n") do |file, dir|
      identifiers = File.join(dir, 'mapping.tsv')
      result = read_job(:tsv_set_metadata, file, new_key_field: 'Sample', rename_fields: %w[Symbol Rank],
                         cast: 'to_i', new_type: 'double', namespace: 'study',
                         identifiers: identifiers).run
      assert_equal 'Sample', result[:key_field]
      assert_equal %w[Symbol Rank], result[:fields]
      assert_equal :double, result[:type]
      assert_equal 'to_i', result[:cast].to_s
      assert_equal 'study', result[:namespace]
      assert_equal identifiers, result[:identifiers]

      reopened = TSV.open(file, persist: false)
      assert_equal 'Sample', reopened.key_field
      assert_equal %w[Symbol Rank], reopened.fields
      assert_equal :double, reopened.type
      assert_equal :to_i, reopened.cast
      assert_equal 'study', reopened.namespace
      assert_equal identifiers, reopened.identifiers
      assert_equal [[0], [7]], reopened['A']
    end
  end

  def test_set_metadata_bakes_projection_into_the_persisted_table
    with_tsv("#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n") do |file, _dir|
      read_job(:tsv_set_metadata, file, namespace: 'study', fields: ['Score']).run
      reopened = TSV.open(file, persist: false)
      assert_equal %w[Score], reopened.fields
      assert_equal 'study', reopened.namespace
    end
  end

  def test_set_metadata_validates_cast_and_type_before_replacing_source
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n") do |file, _dir|
      before = File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_set_metadata, file, cast: 'to_s').run }
      assert_equal before, File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_set_metadata, file, new_type: 'triple').run }
      assert_equal before, File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_set_metadata, file).run }
      assert_equal before, File.binread(file)
    end
  end

  def test_set_metadata_rejects_duplicate_labels_across_key_and_value_columns
    with_tsv("#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n") do |file, _dir|
      before = File.binread(file)
      message = error_message(read_job(:tsv_set_metadata, file, new_key_field: 'Gene', rename_fields: %w[Gene Score]))
      assert_not_nil message
      assert_match(/Duplicate labels/, message)
      assert_equal before, File.binread(file)
    end
  end

  def test_set_metadata_rejects_key_only_rename_colliding_with_a_value_field
    # Regression: the duplicate-label check only ran inside the
    # rename_fields branch, so a key-only rename (new_key_field with
    # rename_fields OMITTED) silently rewrote the source with a key label
    # equal to an existing value field label.
    with_tsv("#: :type=:single\n#ID\tScore\nA\t1\n") do |file, _dir|
      before = File.binread(file)
      message = error_message(read_job(:tsv_set_metadata, file, new_key_field: 'Score'))
      assert_not_nil message
      assert_match(/Duplicate labels/, message)
      assert_equal before, File.binread(file), 'the collision is rejected before the source is rewritten'
    end
  end

  def test_set_metadata_rejects_csv_sources
    with_tsv("ID,Score\nA,12\n", 'source.csv') do |file, _dir|
      before = File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_set_metadata, file, namespace: 'study').run }
      assert_equal before, File.binread(file)
    end
  end

  # ------------------------------------------------------------------
  # tsv_read
  # ------------------------------------------------------------------

  def test_read_returns_scout_tsv_text_and_supports_csv_empty_header_hash
    with_tsv("ID,Gene\nA,TP53\n", 'source.csv') do |file, _dir|
      read = read_job(:tsv_read, file, type: 'single', sep: ',', header_hash: '').run
      assert_kind_of String, read
      table = TSV.open(StringIO.new(read), persist: false)
      assert_equal :single, table.type
      assert_equal %w[Gene], table.fields
      assert_match(/#ID\tGene\nA\tTP53\n\z/, read)

      output = run_with_harness_return_path(:tsv_read, file: file, type: 'single', sep: ',', header_hash: '')
      assert_equal read, File.binread(output)
    end
  end

  def test_read_supports_scout_open_options_and_exact_key_subset
    with_tsv("#: :type=:single\n#ID\tScore\nA\t01\nB\t02\n") do |file, _dir|
      text = read_job(:tsv_read, file, type: 'single', keys: ['B'], cast: 'to_i').run
      subset = TSV.open(StringIO.new(text), persist: false)
      assert_equal ['B'], subset.keys
      # tsv_read forwards the cast to TSV.open, so the cast is parser metadata
      # recorded in the product header: a consumer reopening WITHOUT a second
      # cast gets integers (regression: cast used to be validated then dropped,
      # and this suite re-applied the cast manually to conceal it).
      assert_equal :to_i, subset.cast
      assert_equal 2, subset['B']
      # The product renders the cast values: no second cast is needed.
      assert_match(/^#: :cast=:to_i/, text)
    end
  end

  def test_read_renames_header_labels_without_touching_keys_or_the_source
    with_tsv("#: :type=:single\n#ID\tScore\nG2\t4\n") do |file, _dir|
      before = File.binread(file)
      out = run_with_harness_return_path(:tsv_read, file: file, type: 'single', new_key_field: 'Accession')
      table = TSV.open(out, persist: false)
      assert_equal 'Accession', table.key_field
      assert_equal ['G2'], table.keys
      assert_equal '4', table['G2']
      assert_equal before, File.binread(file), 'the source is never modified by tsv_read'
    end
  end

  def test_read_rejects_unsupported_casts
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n") do |file, _dir|
      assert_raise(ParameterException) { read_job(:tsv_read, file, cast: 'to_s').run }
      assert_raise(ParameterException) { read_job(:tsv_read, file, sep: ',', cast: 'to_s').run }
    end
  end

  def test_prepared_tsv_is_consumed_by_query_using_canonical_defaults
    with_tsv("ID,Score\nA,12|13\n", 'source.csv') do |csv, dir|
      prepared = read_job(:tsv_read, csv, type: 'double', sep: ',', header_hash: '').run
      canonical = File.join(dir, 'prepared.tsv')
      File.write(canonical, prepared)
      result = read_job(:tsv_query, canonical, keys: ['A']).run
      assert_equal 'ID', result[:key_field]
      assert_equal %w[Score], result[:fields]
      assert_equal [['12', '13']], result[:queries].first[:value]
    end
  end

  # ------------------------------------------------------------------
  # tsv_query field resolver
  # ------------------------------------------------------------------

  def test_query_returns_request_order_missing_keys_and_recursively_casts_without_column
    with_tsv("#: :type=:double\n#ID\tScore\nA\t12|13\nB\t20\n") do |file, _dir|
      result = read_job(:tsv_query, file, keys: %w[B missing A], cast: 'to_i').run
      assert_equal %w[B missing A], result[:queries].map { |entry| entry[:key] }
      assert_equal [[[20]], nil, [[12, 13]]], result[:queries].map { |entry| entry[:value] }
      assert_equal ['missing'], result[:missing_keys]

      selected = read_job(:tsv_query, file, keys: ['A'], column: 'key', cast: 'to_i').run
      assert_equal 'A', selected[:queries].first[:value]

      list_file = File.join(File.dirname(file), 'list.tsv')
      File.write(list_file, "#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n")
      list_query = read_job(:tsv_query, list_file, keys: ['A'], column: 'Score').run
      assert_equal ['7'], list_query[:queries].first[:value]
    end
  end

  def test_query_accepts_the_actual_key_label_the_key_alias_and_value_fields
    with_tsv("#Gene ID\tScore\nG2\t4\n", 'gene.tsv') do |file, _dir|
      by_label = read_job(:tsv_query, file, keys: ['G2'], column: 'Gene ID').run
      assert_equal 'G2', by_label[:queries].first[:value]
      by_alias = read_job(:tsv_query, file, keys: ['G2'], column: 'key').run
      assert_equal 'G2', by_alias[:queries].first[:value]
      by_value = read_job(:tsv_query, file, keys: ['G2'], column: 'Score').run
      assert_equal ['4'], by_value[:queries].first[:value]
    end
  end

  def test_query_lists_the_actual_key_label_and_value_fields_on_unknown_names
    with_tsv("#Gene ID\tScore\nG2\t4\n", 'gene.tsv') do |file, _dir|
      message = error_message(read_job(:tsv_query, file, keys: ['G2'], column: 'Other'))
      assert_not_nil message
      assert_match(/Unknown TSV column "Other"/, message)
      assert_match(/Key field: "Gene ID"/, message)
      assert_match(/Available value fields: \["Score"\]/, message)
    end
  end

  def test_query_keeps_the_key_alias_working_when_a_value_field_is_named_key
    with_tsv("#Gene ID\tkey\tScore\nG2\tG\t4\n", 'alias.tsv') do |file, _dir|
      by_alias = read_job(:tsv_query, file, keys: ['G2'], column: 'key').run
      assert_equal 'G2', by_alias[:queries].first[:value], 'the alias still means the key column'
      escaped = read_job(:tsv_query, file, keys: ['G2'], column: '@key').run
      assert_equal ['G'], escaped[:queries].first[:value], '@key selects the literal value field'
    end
  end

  def test_query_rejects_invalid_cast_and_conflicting_field_column
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n") do |file, _dir|
      assert_raise(ParameterException) { read_job(:tsv_query, file, keys: ['A'], cast: 'to_s').run }
      assert_raise(ParameterException) { read_job(:tsv_query, file, keys: ['A'], column: 'Other').run }
      assert_raise(ParameterException) { read_job(:tsv_query, file, keys: ['A'], column: 'Score', field: 'Score').run }
    end
  end

  def test_query_caps_the_number_of_requested_keys
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n") do |file, _dir|
      many = (1..(Workspace::TSVTasks::QUERY_KEY_LIMIT + 1)).map(&:to_s)
      message = error_message(read_job(:tsv_query, file, keys: many))
      assert_not_nil message
      assert_match(/capped/, message)
      within = (1..Workspace::TSVTasks::QUERY_KEY_LIMIT).map(&:to_s)
      result = read_job(:tsv_query, file, keys: within).run
      assert_equal Workspace::TSVTasks::QUERY_KEY_LIMIT, result[:queries].length
    end
  end

  # ------------------------------------------------------------------
  # tsv_edit
  # ------------------------------------------------------------------

  def test_edit_field_and_full_row_mutate_source_and_return_updated_output
    with_tsv("#: :type=:double\n#ID\tGene\tScore\nA\tTP53|BRCA1\t1|2\n") do |file, _dir|
      field_output = run_with_harness_return_path(:tsv_edit, file: file, key: 'A', field: 'Gene', value: 'MYC|ALK')
      assert_equal [%w[MYC ALK], %w[1 2]], TSV.open(file, persist: false)['A']
      assert_equal File.binread(file), File.binread(field_output)

      row_output = run_with_harness_return_path(:tsv_edit, file: file, key: 'A', row: '[["EGFR"], ["7", "8"]]')
      reopened = TSV.open(file, persist: false)
      assert_equal [%w[EGFR], %w[7 8]], reopened['A']
      assert_equal :double, reopened.type
      assert_equal %w[Gene Score], reopened.fields
      assert_equal File.binread(file), File.binread(row_output)
    end
  end

  def test_invalid_edit_never_changes_source_or_materializes_an_output
    with_tsv("#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n") do |file, _dir|
      before = File.binread(file)
      assert_raise(ParameterException) do
        read_job(:tsv_edit, file, key: 'A', row: '["bad"]').run
      end
      assert_equal before, File.binread(file)
    end
  end

  def test_edit_validates_row_shapes_missing_keys_fields_and_flat_field_edits
    with_tsv("#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n") do |file, _dir|
      before = File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_edit, file, key: 'A', row: '["only-one"]').run }
      assert_equal before, File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_edit, file, key: 'A', field: 'Missing', value: 'x').run }
      assert_equal before, File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_edit, file, key: 'absent', field: 'Gene', value: 'x').run }
      assert_equal before, File.binread(file)
    end
    with_tsv("#: :type=:flat\n#ID\tGene\nA\tTP53|BRCA1\n") do |file, _dir|
      assert_raise(ParameterException) { read_job(:tsv_edit, file, key: 'A', field: 'Gene', value: 'x').run }
      output = run_with_harness_return_path(:tsv_edit, file: file, key: 'A', row: '["EGFR", "MYC"]')
      assert_equal %w[EGFR MYC], TSV.open(output, persist: false)['A']
      assert_equal %w[EGFR MYC], TSV.open(file, persist: false)['A']
    end
  end

  def test_edit_row_branch_rejects_tabs_newlines_and_inner_separators
    with_tsv("#: :type=:list\n#ID\tGene\tScore\nA\tTP53\t7\n") do |file, _dir|
      before = File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_edit, file, key: 'A', row: '["EG\tFR", "7"]').run }
      assert_equal before, File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_edit, file, key: 'A', row: '["EG\nFR", "7"]').run }
      assert_equal before, File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_edit, file, key: 'A', row: '["EG|FR", "7"]').run }
      assert_equal before, File.binread(file)
    end
    with_tsv("#: :type=:double\n#ID\tGene\nA\tTP53|BRCA1\n") do |file, _dir|
      before = File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_edit, file, key: 'A', row: '[["EG|FR"]]').run }
      assert_equal before, File.binread(file)
    end
  end

  def test_source_mutations_reject_read_only_files
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n") do |file, _dir|
      original_mode = File.stat(file).mode & 0o777
      before = File.binread(file)
      File.chmod(0o444, file)
      assert_raise(ParameterException) { read_job(:tsv_edit, file, key: 'A', field: 'Score', value: '13').run }
      assert_equal before, File.binread(file)
      assert_raise(ParameterException) { read_job(:tsv_set_metadata, file, new_key_field: 'Sample').run }
      assert_equal before, File.binread(file)
    ensure
      File.chmod(original_mode, file) if original_mode
    end
  end

  def test_source_mutations_reject_symlink_inputs_without_touching_target
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n", 'target.tsv') do |target, dir|
      link = File.join(dir, 'source-link.tsv')
      File.symlink(target, link)
      before = File.binread(target)
      assert_raise(ParameterException) { read_job(:tsv_edit, link, key: 'A', field: 'Score', value: '13').run }
      assert_equal before, File.binread(target)
    end
  end

  def test_read_rejects_unusable_source_write_for_info_override_and_edit
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n") do |file, dir|
      # Directory permissions are checked explicitly; simulate an unusable directory
      # through a symlink source, which is rejected consistently even when tests run as root.
      link = File.join(dir, 'source-link.tsv')
      File.symlink(file, link)
      assert_raise(ParameterException) { read_job(:tsv_set_metadata, link, new_key_field: 'Sample').run }
      assert_raise(ParameterException) { read_job(:tsv_edit, link, key: 'A', field: 'Score', value: '13').run }
    end
  end

  # ------------------------------------------------------------------
  # tsv_merge / tsv_attach
  # ------------------------------------------------------------------

  def test_merge_replaces_entire_colliding_row_or_explicitly_zips_double_values
    with_tsv("#: :type=:double\n#ID\tGene\tScore\nA\tLEFT\t1\nB\tONLY_LEFT\t2\n", 'left.tsv') do |left, dir|
      right = File.join(dir, 'right.tsv')
      File.write(right, "#: :type=:double\n#ID\tGene\tScore\nA\tRIGHT\t3\nC\tONLY_RIGHT\t4\n")
      replace_path = run_with_harness_return_path(:tsv_merge, left: left, right: right, strategy: 'replace')
      replaced = TSV.open(replace_path, persist: false)
      assert_equal [%w[RIGHT], %w[3]], replaced['A']
      assert_equal [%w[ONLY_LEFT], %w[2]], replaced['B']
      assert_equal [%w[ONLY_RIGHT], %w[4]], replaced['C']

      zip_path = run_with_harness_return_path(:tsv_merge, left: left, right: right, strategy: 'zip')
      zipped = TSV.open(zip_path, persist: false)
      assert_equal [%w[LEFT RIGHT], %w[1 3]], zipped['A']
      assert_equal "#: :type=:double\n#ID\tGene\tScore\nA\tLEFT\t1\nB\tONLY_LEFT\t2\n", File.read(left)
    end
  end

  def test_attach_copies_source_and_harness_can_return_job_path
    with_tsv("#: :type=:double\n#ID\tGene\nA\tTP53\nB\tBRCA1\n", 'source.tsv') do |source, dir|
      other = File.join(dir, 'other.tsv')
      File.write(other, "#: :type=:double\n#ID\tGene\tRank\nX\tTP53\t1\n")
      before = File.binread(source)
      path = run_with_harness_return_path(:tsv_attach, source: source, other: other,
                                          match_key: 'Gene', other_key: 'Gene')
      attached = TSV.open(path, persist: false)
      assert_equal %w[Gene Rank], attached.fields
      assert_equal [%w[TP53], %w[1]], attached['A']
      assert_equal [%w[BRCA1], []], attached['B']
      assert_equal before, File.binread(source)
    end
  end

  # ------------------------------------------------------------------
  # tsv_translate
  # ------------------------------------------------------------------

  def test_translate_values_through_identifiers_and_harness_returns_job_path
    with_tsv("#: :type=:double\n#ID\tGene\nA\tTP53|BRCA1\n", 'source.tsv') do |file, dir|
      identifiers = File.join(dir, 'identifiers.tsv')
      File.write(identifiers, "#Gene\tAccession\nTP53\tP04637\nBRCA1\tP38398\n")
      before = File.binread(file)
      output = run_with_harness_return_path(:tsv_translate, file: file, field: 'Gene',
                                            target_format: 'Accession', identifiers: identifiers)
      translated = TSV.open(output, persist: false)
      assert_equal 'Accession', translated.fields.first
      assert_equal %w[P04637 P38398], translated['A'].first
      assert_equal before, File.binread(file)
    end
  end

  # ------------------------------------------------------------------
  # tsv_sort
  # ------------------------------------------------------------------

  def test_sort_by_numeric_field_pages_and_returns_keys_or_tsv
    with_tsv("#: :type=:double\n#ID\tScore\tGene\nA\t10\tAlpha\nB\t2\tBeta\nC\t30\tGamma\n") do |file, _dir|
      keys = read_job(:tsv_sort, file, column: 'Score', cast: 'to_i', page: 1, page_size: 2, just_keys: true).run
      assert_equal %w[B A], keys[:keys]
      assert_equal 3, keys[:total_keys]

      floats = read_job(:tsv_sort, file, column: 'Score', cast: 'to_f', page: 1, page_size: 2, just_keys: true).run
      assert_equal %w[B A], floats[:keys]

      page = read_job(:tsv_sort, file, column: 'Score', cast: 'to_i', direction: 'descending', page: 2, page_size: 2).run
      table = TSV.open(StringIO.new(page[:tsv]), persist: false)
      assert_equal ['B'], table.keys
      assert_equal %w[Score Gene], table.fields
      assert_equal ['2'], table['B'][0]

      all_keys = read_job(:tsv_sort, file, column: 'key', just_keys: true).run
      assert_equal %w[A B C], all_keys[:keys]
    end
  end

  def test_sort_accepts_the_actual_key_label_and_matches_the_alias_order
    with_tsv("#Gene ID\tScore\nG2\t4\nG1\t9\n", 'gene.tsv') do |file, _dir|
      by_label = read_job(:tsv_sort, file, column: 'Gene ID', just_keys: true).run
      by_alias = read_job(:tsv_sort, file, column: 'key', just_keys: true).run
      assert_equal by_alias[:keys], by_label[:keys], 'sorting by the key label and by the alias agree'
      assert_equal %w[G1 G2], by_label[:keys]
    end
  end

  def test_sort_follows_the_resolved_field_when_key_and_field_orders_oppose
    # Row-key order (Row1 < Row2 < Row3) is OPPOSITE to the literal value
    # field "key" order (aaa < mmm < zzz). The column spellings:
    #   '@key' -> the VALUE field "key" (resolve_field -> index 0)
    #   'key'  -> the reserved alias     (resolve_field -> :key)
    # Regression: tsv_sort passed the caller's STRING to TSV#page; page()s
    # internal coercion turned "key" into the :key alias for BOTH spellings
    # (or crashed traverse on scout-gear 10.13.1), so @key sorted by the row
    # key. The RESOLVED field must be what reaches TSV#page.
    with_tsv("#: :type=:double\n#ID\tkey\nRow1\tzzz\nRow2\tmmm\nRow3\taaa\n", 'opposite.tsv') do |file, _dir|
      by_escape = read_job(:tsv_sort, file, column: '@key', just_keys: true, page_size: 10).run
      assert_equal %w[Row3 Row2 Row1], by_escape[:keys], 'sort by the literal "key" value field follows the FIELD order'

      by_alias = read_job(:tsv_sort, file, column: 'key', just_keys: true, page_size: 10).run
      assert_equal %w[Row1 Row2 Row3], by_alias[:keys], 'sort by the reserved alias follows the ROW-KEY order'

      by_label = read_job(:tsv_sort, file, column: 'ID', just_keys: true, page_size: 10).run
      assert_equal by_alias[:keys], by_label[:keys], 'the key label and the alias agree'
    end
  end

  def test_sort_unknown_column_lists_the_actual_key_label_and_value_fields
    with_tsv("#Gene ID\tScore\nG2\t4\n", 'gene.tsv') do |file, _dir|
      message = error_message(read_job(:tsv_sort, file, column: 'Other'))
      assert_not_nil message
      assert_match(/Key field: "Gene ID"/, message)
      assert_match(/Available value fields: \["Score"\]/, message)
    end
  end

  def test_sort_defaults_to_a_bounded_page_and_reports_truncation
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n") do |file, _dir|
      page = read_job(:tsv_sort, file, just_keys: true).run
      assert_equal Workspace::TSVTasks::DEFAULT_SORT_PAGE, page[:page_size], 'omitted page_size is bounded'
      assert_equal ['A'], page[:keys]
      assert_equal false, page[:truncated]
    end
  end

  def test_sort_validates_column_cast_direction_and_pagination
    with_tsv("#: :type=:single\n#ID\tScore\nA\t12\n") do |file, _dir|
      assert_raise(ParameterException) { read_job(:tsv_sort, file, column: 'Other').run }
      assert_raise(ParameterException) { read_job(:tsv_sort, file, cast: 'to_s').run }
      assert_raise(ParameterException) { read_job(:tsv_sort, file, direction: 'sideways').run }
      assert_raise(ParameterException) { read_job(:tsv_sort, file, page: 0).run }
      assert_raise(ParameterException) { read_job(:tsv_sort, file, page_size: 0).run }
      empty_page = read_job(:tsv_sort, file, page: 3, page_size: 1, just_keys: true).run
      assert_equal [], empty_page[:keys]
    end
  end

  def test_sort_float_cast_and_full_tsv_preserve_sorted_key_order
    with_tsv("#: :type=:double\n#ID\tScore\tTags\nA\t10.1\ta|b\nB\t2.2\tc\nC\t1.5\td\n") do |file, _dir|
      keys = read_job(:tsv_sort, file, column: 'Score', cast: 'to_f', just_keys: true).run
      assert_equal %w[C B A], keys[:keys]

      page = read_job(:tsv_sort, file, column: 'Score', cast: 'to_f').run
      table = TSV.open(StringIO.new(page[:tsv]), persist: false)
      assert_equal %w[C B A], table.keys
      assert_equal ['d'], table['C'][1]
    end
  end
end
