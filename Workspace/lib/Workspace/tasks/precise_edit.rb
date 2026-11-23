require 'scout/llm/text_edit'

module Workspace
  input :path, :path, 'File to mutate', nil, required: true
  input :operation, :select, 'Mutation operation', nil, required: true, select_options: %w(replace insert delete)
  input :selector, :text, 'Exact text to find', nil, required: true
  input :replacement, :text, 'Replacement or inserted content', nil, required: true
  input :expect_matches, :integer, 'Required exact number of selector matches', nil, required: true
  input :expected_hash, :string, 'Optional SHA-256 hash of the original file'
  extension :json
  task :precise_edit => :json do |path, operation, selector, replacement, expect_matches, expected_hash|
    file = normalize(path, :write)
    raise ParameterException, "File not found: #{file}" unless Open.exists?(file)
    raise ParameterException, "File is a directory: #{file}" if Open.directory?(file)

    original = Open.read(file)
    begin
      updated, result = ScoutTextEdit.apply(original, operation: operation, selector: selector,
        replacement: replacement.to_s, expect_matches: expect_matches, expected_hash: expected_hash)
    rescue ArgumentError => e
      raise ParameterException, e.message
    end
    Open.write(file, updated) if result[:verification][:changed]
    result.merge(resolved_path: file, existence: true)
  end

  export_exec :precise_edit
end
