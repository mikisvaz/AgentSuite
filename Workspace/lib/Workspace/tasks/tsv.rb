require 'json'
require 'tempfile'
require 'scout'

module Workspace
  module TSVTasks
    TYPES = %w(single list flat double).freeze
    MERGES = %w(true false concat).freeze
    # Bounded interactive default for tsv_sort paging. The task has no way to
    # distinguish "interactive page" from "persisted product" (the harness
    # persists whatever the task returns), so the page itself is bounded; a
    # caller that needs the whole table supplies an explicit page_size.
    DEFAULT_SORT_PAGE = 500
    # Upper bound on the number of keys a single tsv_query call materializes,
    # so a single tool call cannot ingest an unbounded amount of a table.
    QUERY_KEY_LIMIT = 5000
    # The string a caller can use to address the key column even when a value
    # field is literally named "key": a leading '@' forces value-field lookup.
    FIELD_ESCAPE_PREFIX = '@'
    KEY_ALIAS = 'key'
    module_function

    def optional(value)
      value.nil? || value == false || (value.respond_to?(:empty?) && value.empty?)
    end

    # Existence-only check. Grant checks happen through the shared read policy
    # (normalize) in each task body before any file is opened.
    def file!(path)
      raise ParameterException, "TSV file not found: #{path}" unless File.file?(path.to_s)
    end

    def type!(type)
      raise ParameterException, 'type must be single, list, flat, or double' unless optional(type) || TYPES.include?(type.to_s)
    end

    def merge_absent?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end

    def merge_option(value)
      return nil if merge_absent?(value)
      raise ParameterException, 'merge must be true, false, or concat' unless MERGES.include?(value.to_s)
      {'true' => true, 'false' => false, 'concat' => :concat}.fetch(value.to_s)
    end

    def open_options(type:, key_field:, fields:, sep:, sep2:, header_hash:, merge: nil,
                     one2one: false, identifiers: nil, namespace: nil, field: nil, cast: nil)
      options = {sep: sep, sep2: sep2, header_hash: header_hash, one2one: one2one, persist: false}
      options[:type] = type.to_sym unless optional(type)
      options[:key_field] = key_field unless optional(key_field)
      options[:fields] = fields unless optional(fields)
      options[:merge] = merge_option(merge) unless merge_absent?(merge)
      options[:identifiers] = identifiers unless optional(identifiers)
      options[:namespace] = namespace unless optional(namespace)
      options[:cast] = cast.to_sym unless optional(cast)
      options[:field] = field unless optional(field)
      options
    end

    def cast!(cast)
      return nil if optional(cast)
      # Native reads and CSV reads share this allowlist so both entry points
      # accept exactly the same casts.
      raise ParameterException, 'cast must be to_i or to_f' unless %w[to_i to_f].include?(cast.to_s)
      cast.to_sym
    end

    # ---------------------------------------------------------------
    # Shared field resolver (tsv_query / tsv_sort / anywhere a column
    # name must become :key or a value-field index).
    #
    # Accepted spellings:
    #   * the table's CURRENT key field label  -> :key
    #   * the alias "key"                      -> :key
    #   * "@key"                               -> the value field "key"
    #   * "@" + any label                      -> that value field only
    #   * any other string                     -> that value field
    #
    # Unknown names raise listing the actual key label and the available
    # value fields.
    # ---------------------------------------------------------------
    def resolve_field(table, name)
      requested = name.to_s
      raise ParameterException, 'column cannot be empty' if requested.empty?
      key_label = table.key_field.to_s
      value_fields = Array(table.fields).map(&:to_s)

      if requested.start_with?(FIELD_ESCAPE_PREFIX)
        label = requested[1..]
        index = value_fields.index(label)
        raise unknown_field(name, key_label, value_fields) if index.nil?
        return index
      end

      return :key if requested == KEY_ALIAS || requested == key_label

      index = value_fields.index(requested)
      raise unknown_field(name, key_label, value_fields) if index.nil?
      index
    end

    def unknown_field(name, key_label, value_fields)
      hint = if Array(value_fields).include?(KEY_ALIAS)
               " (a value field is literally named \"key\": use \"#{FIELD_ESCAPE_PREFIX}key\" to select it and \"#{KEY_ALIAS}\" or the key label for the key column)"
             else
               ''
             end
      ParameterException.new("Unknown TSV column #{name.inspect}. Key field: #{key_label.inspect}. Available value fields: #{value_fields.inspect}#{hint}")
    end

    # An optional column selection that may legitimately be absent.
    def resolve_optional_field(table, name)
      return nil if optional(name)
      resolve_field(table, name)
    end

    def rename_metadata!(table, key_name: nil, field_names: nil, namespace: nil, identifiers: nil,
                         cast: nil, type: nil)
      unless optional(key_name)
        raise ParameterException, 'key field name cannot be empty' if key_name.to_s.empty?
        raise duplicate_label_error(key_name.to_s, Array(table.fields).map(&:to_s)) if Array(table.fields).map(&:to_s).include?(key_name.to_s)
        table.key_field = key_name.to_s
      end
      unless optional(field_names)
        names = Array(field_names).map(&:to_s)
        raise ParameterException, "expected #{Array(table.fields).length} field names" unless names.length == Array(table.fields).length
        raise ParameterException, 'field names must be nonempty and unique' if names.any?(&:empty?) || names.uniq.length != names.length
        raise duplicate_label_error(table.key_field, names) if names.include?(table.key_field.to_s)
        table.fields = names
      end
      table.namespace = namespace unless optional(namespace)
      table.identifiers = identifiers unless optional(identifiers)
      table.cast = cast!(cast) unless optional(cast)
      unless optional(type)
        target_type = type.to_sym
        raise ParameterException, 'type must be single, list, flat, or double' unless TYPES.include?(target_type.to_s)
        table = table.public_send("to_#{target_type}") unless table.type.to_sym == target_type
      end
      table
    end

    def duplicate_label_error(key_label, field_names)
      ParameterException.new("Duplicate labels are not allowed: value fields #{field_names.inspect} collide with key field #{key_label.inspect}")
    end

    def copy(value)
      value.is_a?(Array) ? value.map { |item| copy(item) } : value
    end

    def clone_table(table)
      metadata = table.annotation_hash.reject { |name, _| name.to_sym == :filename }
      result = TSV.setup({}, metadata)
      table.each { |key, value| result[key] = copy(value) }
      result
    end

    def right_replacement(left, right)
      result = clone_table(left)
      right.each { |key, value| result[key] = copy(value) }
      result
    end

    def render(table, sep: "\t", sep2: '|', header_hash: '#')
      clean = clone_table(table)
      clean.to_s(preamble: true, sep: sep, sep2: sep2, header_hash: header_hash).to_s
    end

    def canonical_render(table)
      render(table, sep: "\t", sep2: '|', header_hash: '#')
    end

    def replace_source!(path, text)
      source = File.expand_path(path.to_s)
      raise ParameterException, "TSV source must be a regular non-symlink file: #{path}" unless File.file?(source) && !File.symlink?(source)
      directory = File.dirname(source)
      source_mode = File.stat(source).mode & 0o7777
      directory_mode = File.stat(directory).mode & 0o7777
      writable = (source_mode & 0o222) != 0 && (directory_mode & 0o222) != 0 && File.writable?(source) && File.writable?(directory)
      raise ParameterException, "TSV source is not writable: #{path}" unless writable
      tempfile = Tempfile.new(['.workspace-tsv-', '.tmp'], directory)
      begin
        tempfile.binmode
        tempfile.write(text)
        tempfile.flush
        tempfile.fsync
        tempfile.close
        File.chmod(source_mode, tempfile.path)
        File.rename(tempfile.path, source)
      ensure
        tempfile.close! if tempfile
      end
      source
    rescue SystemCallError => e
      raise ParameterException, "Could not atomically update TSV source #{path}: #{e.message}"
    end

    # ---------------------------------------------------------------
    # Authorization. Reading and rewriting a source must both go
    # through the shared Workspace read/write policy (normalize)
    # BEFORE the file is opened, not just before the rename.
    # ---------------------------------------------------------------

    def read_input!(path, what: 'TSV file')
      file!(path)
      normalize(path, :read)
    end

    # Authorize a mutation (rewrite in place) before any tempfile is created.
    def authorize_mutation!(path)
      normalize(path, :write)
      path
    end

    # A metadata value that is only ever recorded (never opened) needs no
    # authorization; an identifier mapping that will actually be READ does.
    def identifier_read!(identifiers)
      return nil if optional(identifiers)
      read_input!(identifiers, what: 'identifier mapping')
    end

    # Persisted rewrites of a CSV source must round-trip through real CSV
    # quoting. Scout's TSV dumper has no CSV mode, so the combination
    # (CSV source + in-place mutation) is rejected instead of corrupt.
    def reject_csv_mutation!(file, sep)
      raise ParameterException, 'In-place mutation of a CSV source is unsupported (Scout renders TSV, not quoted CSV). Normalize it first with tsv_read.' if csv_source?(file, sep)
    end

    def csv_source?(file, sep)
      sep.to_s == ',' || file.to_s.end_with?('.csv')
    end

    def scalar?(value)
      value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
    end

    def stringify(values)
      values.map do |value|
        raise ParameterException, 'row values must be JSON scalars' unless scalar?(value)
        value.nil? ? nil : value.to_s
      end
    end

    # Row values in the JSON branch must round-trip through the physical
    # rendering: tabs and newlines cannot be stored, and the inner separator
    # would silently change the row's shape, so they are rejected.
    def check_cell_text(value)
      raise ParameterException, 'row values cannot contain tabs or newlines' if value.to_s.match?(/[\t\r\n]/)
      raise ParameterException, "row values cannot contain the inner separator '|'" if value.to_s.include?('|')
    end

    def json_row(text)
      JSON.parse(text.to_s)
    rescue JSON::ParserError => e
      raise ParameterException, "row must be valid JSON: #{e.message}"
    end

    def validate_row(type, row, fields, sep2: '|')
      case type.to_sym
      when :single
        raise ParameterException, 'single TSV row must be one scalar' unless scalar?(row)
        check_cell_text(row)
        row.nil? ? nil : row.to_s
      when :list
        raise ParameterException, "list row must contain #{fields} scalar fields" unless row.is_a?(Array) && row.length == fields && row.all? { |v| scalar?(v) }
        row.each { |v| check_cell_text(v) }
        stringify(row)
      when :flat
        raise ParameterException, 'flat row must be an array of scalar values' unless row.is_a?(Array) && row.all? { |v| scalar?(v) }
        row.each { |v| check_cell_text(v) }
        stringify(row)
      when :double
        valid = row.is_a?(Array) && row.length == fields && row.all? { |cell| cell.is_a?(Array) && cell.all? { |v| scalar?(v) } }
        raise ParameterException, "double row must contain #{fields} arrays of scalars" unless valid
        row.map { |cell| cell.each { |v| check_cell_text(v) }; stringify(cell) }
      else
        raise ParameterException, "unsupported TSV type: #{type}"
      end
    end

    # Physical input records behind a materialized table (dupes collapse via
    # merge; separators may make one record out of many values). Lines starting
    # with the current header marker are metadata, not records. This is a
    # heuristic count: quoted embedded newlines (CSV) are not handled.
    def source_records(path, header_hash: '#')
      marker = header_hash.to_s
      count = 0
      File.open(path.to_s, 'r').each_line { |line| count += 1 unless marker != '' && line.start_with?(marker) }
      count
    rescue StandardError
      nil
    end

    def bounded_keys(keys)
      keys = Array(keys).map(&:to_s)
      raise ParameterException, "query is capped at #{QUERY_KEY_LIMIT} keys; request a subset" if keys.length > QUERY_KEY_LIMIT
      keys
    end

  end

  # Authorization is the shared read/write policy: each task body calls
  # `normalize` (the filesystem.rb helper, mixed into every step) on every
  # materialized input before the file is opened, and on the source again
  # with :write before any rewrite.

  input :file, :path, 'TSV file path', nil, required: true
  input :key_field, :string, 'Source column to index by (input interpretation only; the reported key_field is the actual label)', nil
  input :fields, :array, 'Select value fields', nil
  input :type, :string, 'Source table type: single, list, flat or double', nil
  input :sep, :string, 'Column separator', "\t"
  input :sep2, :string, 'Multi-value separator', '|'
  input :header_hash, :string, 'Header marker', '#'
  input :merge, :string, 'Duplicate-key merge: true, false, concat', nil
  input :one2one, :boolean, 'Use Scout one2one behavior', false
  task tsv_info: :json do |file, key_field, fields, type, sep, sep2, header_hash, merge, one2one|
    TSVTasks.file!(file); TSVTasks.type!(type)
    file = normalize(file, :read)
    open_options = TSVTasks.open_options(type: type, key_field: key_field, fields: fields, sep: sep, sep2: sep2, header_hash: header_hash, merge: merge, one2one: one2one)
    table = if sep == ','
      csv = TSV.csv(file, headers: true, type: (type || :double).to_sym, col_sep: sep)
      if !TSVTasks.optional(key_field) || !TSVTasks.optional(fields)
        selected_fields = TSVTasks.optional(fields) ? csv.fields : Array(fields).map(&:to_s)
        selected_key = TSVTasks.optional(key_field) ? csv.key_field : key_field.to_s
        csv = csv.reorder(selected_key, selected_fields, one2one: one2one, merge: TSVTasks.merge_option(merge), type: (type || :double).to_sym)
      end
      csv
    else
      parser = TSV::Parser.new(file, sep: sep, header_hash: header_hash, type: (type || :double).to_sym)
      parser.traverse(data: false) { |_key, _value, _fields| }
      TSV.open(file, open_options)
    end
    keys = table.keys.length
    value_fields = table.fields || []
    {key_field: table.key_field, fields: value_fields, type: table.type, cast: table.cast,
     namespace: table.namespace, identifiers: table.identifiers,
     source_rows: keys, unique_keys: keys,
     physical_input_records: TSVTasks.source_records(file, header_hash: header_hash),
     entity_field_candidates: value_fields.select { |name| Entity.formats.include?(name) },
     registered_entity_formats: Entity.formats.keys}
  end
  export :tsv_info

  input :file, :path, 'TSV file', nil, required: true
  input :keys, :array, 'Exact keys to retain, empty means all', []
  input :key_field, :string, 'Source column to index by (input interpretation; does not rename)', nil
  input :fields, :array, 'Select value fields', nil
  input :type, :string, 'TSV type', :double
  input :sep, :string, 'Column separator', "\t"
  input :sep2, :string, 'Multi-value separator', '|'
  input :header_hash, :string, 'Header marker; empty disables it', '#'
  input :cast, :string, 'Cast parsed values: to_i or to_f', nil
  input :select, :string, 'Scout selection option', nil
  input :grep, :string, 'Scout grep option', nil
  input :merge, :string, 'Duplicate-key merge: true, false, concat', true
  input :one2one, :boolean, 'Use Scout one2one behavior', false
  input :field, :string, 'Scout convenience field option', nil
  input :identifiers, :path, 'Identifier mapping path metadata (recorded only; not opened by this task)', nil
  input :namespace, :string, 'TSV namespace metadata', nil
  input :new_key_field, :string, 'Output label for the key column (renames the header, never the keys)', nil
  input :rename_fields, :array, 'Output labels for the value fields, in order', nil
  input :persist, :boolean, 'Use parser/cache persistence', false
  extension :tsv
  task tsv_read: :string do |file, keys, key_field, fields, type, sep, sep2, header_hash, cast, select, grep, merge, one2one, field, identifiers, namespace, new_key_field, rename_fields, persist|
    TSVTasks.file!(file); TSVTasks.type!(type); TSVTasks.cast!(cast)
    file = normalize(file, :read)
    opts = TSVTasks.open_options(type: type, key_field: key_field, fields: fields, sep: sep,
      sep2: sep2, header_hash: header_hash, merge: merge, one2one: one2one, field: field,
      namespace: namespace, cast: cast)
    if persist && sep != ','
      opts[:persist] = true
      opts[:persist_engine] = 'HDB'
      opts[:persist_path] = File.join(self.files_dir, 'source.hdb')
    end
    table = if sep == ','
      parsed = TSV.csv(file, headers: true, type: (type || :double).to_sym, col_sep: sep)
      source_key = parsed.key_field.to_s
      source_fields = [source_key, *Array(parsed.fields).map(&:to_s)]
      selected_fields = TSVTasks.optional(fields) ? source_fields.drop(1) : Array(fields).map(&:to_s)
      requested_key = TSVTasks.optional(key_field) ? source_key : key_field.to_s
      raise ParameterException, 'merge=false is unsupported for CSV input by TSV.csv' if merge.to_s == 'false'
      selected = if requested_key == source_key && selected_fields == source_fields.drop(1)
        parsed
      else
        raise ParameterException, 'one2one CSV field/key reordering is unsupported' if one2one
        parsed.reorder(requested_key, selected_fields, merge: TSVTasks.merge_option(merge), type: (type || :double).to_sym)
      end
      selected.namespace = namespace unless TSVTasks.optional(namespace)
      selected.identifiers = identifiers unless TSVTasks.optional(identifiers)
      unless TSVTasks.optional(cast)
        casted = TSV.setup({}, selected.annotation_hash)
        selected.each { |row_key, value| casted[row_key] = TSV.cast_value(value, cast.to_sym) }
        selected = casted
      end
      selected = selected.select(select) unless TSVTasks.optional(select)
      unless TSVTasks.optional(grep)
        pattern = Regexp.new(grep.to_s)
        matched = TSV.setup({}, selected.annotation_hash)
        selected.each do |row_key, value|
          matched[row_key] = TSVTasks.copy(value) if [row_key, *Array(value).flatten].join("\t").match?(pattern)
        end
        selected = matched
      end
      case (type || 'double').to_s
      when 'single' then selected.to_single
      when 'list' then selected.to_list
      when 'flat' then selected.to_flat
      else selected
      end
    else
      TSV.open(file, opts)
    end
    table.identifiers = identifiers unless TSVTasks.optional(identifiers)
    table.namespace = namespace unless TSVTasks.optional(namespace)
    unless sep == ','
      table = table.select(select) unless TSVTasks.optional(select)
      table = table.grep(grep) unless TSVTasks.optional(grep)
    end
    wanted = Array(keys).map(&:to_s)
    unless wanted.empty?
      filtered = TSV.setup({}, table.annotation_hash.reject { |n, _| n.to_sym == :filename })
      wanted.uniq.select { |key| table.key?(key) }.sort.each { |key| filtered[key] = TSVTasks.copy(table[key]) }
      table = filtered
    end
    TSVTasks.rename_metadata!(table, key_name: new_key_field, field_names: rename_fields, namespace: namespace, identifiers: identifiers)
    TSVTasks.canonical_render(table)
  end
  export :tsv_read

  input :file, :path, 'TSV file', nil, required: true
  input :keys, :array, 'Keys to fetch', [], required: true
  input :key_field, :string, 'Source column to index by (input interpretation only)', nil
  input :fields, :array, 'Select fields', nil
  input :type, :string, 'TSV type', nil
  input :cast, :string, 'to_i or to_f', nil
  input :column, :string, 'Value field name, the exact current key field label, or the reserved alias "key"; prefix with @ to select a value field literally named "key"', nil
  input :merge, :string, 'Duplicate-key merge', nil
  input :one2one, :boolean, 'Use Scout one2one behavior', false
  input :field, :string, 'Scout convenience field option', nil
  task tsv_query: :json do |file, keys, key_field, fields, type, cast, column, merge, one2one, field|
    TSVTasks.file!(file); TSVTasks.type!(type); TSVTasks.cast!(cast)
    file = normalize(file, :read)
    raise ParameterException, 'field and column cannot both be used' unless TSVTasks.optional(field) || TSVTasks.optional(column)
    table = TSV.open(file, TSVTasks.open_options(type: type, key_field: key_field, fields: fields,
      sep: "\t", sep2: '|', header_hash: '#', merge: merge, one2one: one2one, field: field))
    selected = TSVTasks.optional(column) ? nil : column.to_s
    column_name = selected
    index = TSVTasks.resolve_optional_field(table, selected)
    raise ParameterException, 'Named-column queries are unsupported for flat TSVs' if index.is_a?(Integer) && table.type.to_sym == :flat
    queries = TSVTasks.bounded_keys(keys).map do |key|
      found = table.key?(key)
      value = if !found then nil
              elsif index == :key then key
              elsif index.nil? then table[key]
              else table.type.to_sym == :single ? table[key] : (table.type.to_sym == :list ? [table[key][index]] : (table.type.to_sym == :double ? table[key][index] : nil))
              end
      value = index == :key ? value : TSV.cast_value(value, cast.to_sym) if cast && found
      {key: key, found: found, value: value}
    end
    {key_field: table.key_field, fields: table.fields || [], type: table.type, column: column_name,
     queries: queries, missing_keys: queries.reject { |q| q[:found] }.map { |q| q[:key] }}
  end
  export :tsv_query

  input :file, :path, 'TSV file', nil, required: true
  input :key, :string, 'Existing key', nil, required: true
  input :field, :string, 'Field for scalar edit; omit for row replacement', nil
  input :value, :text, 'Replacement value', nil
  input :row, :text, 'Full row JSON replacement', nil
  input :type, :string, 'Source table type: single, list, flat or double', nil
  extension :tsv
  task tsv_edit: :string do |file, key, field, value, row, type|
    TSVTasks.file!(file); TSVTasks.type!(type)
    file = normalize(file, :read)
    row = nil if row == ''
    raise ParameterException, 'specify either row or field/value, not both' if row && field
    raise ParameterException, 'provide a row or both field and value' if !row && (!field || value.nil?)
    table = TSV.open(file, {sep: "\t", sep2: '|', header_hash: '#', persist: false}.tap { |opts| opts[:type] = type.to_sym unless TSVTasks.optional(type) })
    kind = table.type.to_sym
    raise ParameterException, "Unknown TSV key: #{key}" unless table.key?(key.to_s)
    names = Array(table.fields).map(&:to_s)
    if row
      table[key.to_s] = TSVTasks.validate_row(kind, TSVTasks.json_row(row), names.length)
    else
      raise ParameterException, 'Named-field edit is unsafe for flat TSV' if kind == :flat
      idx = names.index(field.to_s)
      raise ParameterException, "Unknown TSV field: #{field}" if idx.nil?
      raise ParameterException, 'replacement value cannot contain tabs/newlines' if value.to_s.match?(/[\t\r\n]/)
      case kind
      when :single
        raise ParameterException, 'single TSV requires exactly one value field' unless names.length == 1 && idx.zero?
        raise ParameterException, "replacement value cannot contain the inner separator '|'" if value.to_s.include?('|')
        table[key.to_s] = value.to_s
      when :list
        current = table[key.to_s]
        raise ParameterException, 'malformed list row' unless current.is_a?(Array) && current.length == names.length
        raise ParameterException, "replacement value cannot contain the inner separator '|'" if value.to_s.include?('|')
        updated = current.dup; updated[idx] = value.to_s; table[key.to_s] = updated
      when :double
        current = table[key.to_s]
        raise ParameterException, 'malformed double row' unless current.is_a?(Array) && current.length == names.length && current.all? { |cell| cell.is_a?(Array) }
        updated = TSVTasks.copy(current); updated[idx] = value.to_s.empty? ? [] : value.to_s.split('|', -1); table[key.to_s] = updated
      end
    end
    TSVTasks.reject_csv_mutation!(file, "\t")
    text = TSVTasks.render(table)
    # Mutations are authorized BEFORE the source is opened for rewrite.
    normalize(file, :write)
    TSVTasks.replace_source!(file, text)
    text
  end
  export :tsv_edit

  input :left, :path, 'Left TSV', nil, required: true
  input :right, :path, 'Right TSV', nil, required: true
  input :strategy, :string, 'replace or zip', 'replace'
  extension :tsv
  task tsv_merge: :string do |left, right, strategy|
    TSVTasks.file!(left); TSVTasks.file!(right)
    left = normalize(left, :read); right = normalize(right, :read)
    raise ParameterException, 'strategy must be replace or zip' unless %w[replace zip].include?(strategy.to_s)
    opts = {sep: "\t", sep2: '|', header_hash: '#', persist: false}
    l = TSV.open(left, opts.dup); r = TSV.open(right, opts.dup)
    %i[key_field fields type].each { |attr| raise ParameterException, "TSV #{attr} conflict" unless l.public_send(attr) == r.public_send(attr) }
    metadata = %i[namespace identifiers serializer entity_options]
    conflicts = metadata.select { |name| l.public_send(name) != r.public_send(name) }
    raise ParameterException, "TSV annotation metadata conflict: #{conflicts.join(', ')}" unless conflicts.empty?
    raise ParameterException, 'zip is supported only for double TSVs' if strategy.to_s == 'zip' && l.type.to_sym != :double
    result = if strategy.to_s == 'replace'
      TSVTasks.right_replacement(l, r)
    else
      TSVTasks.clone_table(l).tap { |merged| r.each { |key, value| merged.zip_new(key, TSVTasks.copy(value)) } }
    end
    TSVTasks.canonical_render(result)
  end
  export :tsv_merge

  input :source, :path, 'Source TSV', nil, required: true
  input :other, :path, 'Right TSV', nil, required: true
  input :match_key, :string, 'Source key or field', nil, required: true
  input :other_key, :string, 'Right key or field', nil, required: true
  input :fields, :array, 'Right-side value fields (default non-key fields)', nil
  input :one2one, :boolean, 'Use Scout one-to-one pairing when interpreting matched values', true
  extension :tsv
  task tsv_attach: :string do |source, other, match_key, other_key, fields, one2one|
    TSVTasks.file!(source); TSVTasks.file!(other)
    source = normalize(source, :read); other = normalize(other, :read)
    opts = {sep: "\t", sep2: '|', header_hash: '#', persist: false}
    src = TSV.open(source, opts.dup); rhs = TSV.open(other, opts.dup)
    raise ParameterException, 'flat TSVs cannot be attached' if [src, rhs].any? { |table| table.type.to_sym == :flat }
    sp = src.identify_field(match_key.to_s); rp = rhs.identify_field(other_key.to_s)
    raise ParameterException, "Unknown source match field: #{match_key}" if sp.nil?
    raise ParameterException, "Unknown right match field: #{other_key}" if rp.nil?
    source_name = sp == :key ? src.key_field : src.fields[sp]
    right_name = rp == :key ? rhs.key_field : rhs.fields[rp]
    raise ParameterException, 'right value matching requires list/double TSV' if rp != :key && %i[single flat].include?(rhs.type.to_sym)
    chosen = TSVTasks.optional(fields) ? (rhs.fields || []).map(&:to_s) - [right_name.to_s] : Array(fields).map(&:to_s)
    raise ParameterException, 'No right fields selected' if chosen.empty?
    chosen.each { |name| raise ParameterException, "Unknown right field: #{name}" if rhs.identify_field(name).nil? || rhs.identify_field(name) == :key }
    collisions = chosen & Array(src.fields).map(&:to_s)
    raise ParameterException, "Attached fields conflict with source fields: #{collisions.join(', ')}" unless collisions.empty?
    matches = rp == :key ? rhs.keys : rhs.values.flat_map { |record| value = record[rp]; value.is_a?(Array) ? value : [value] }
    raise ParameterException, 'Repeated right-side match values are unsupported' unless matches.compact.uniq.length == matches.compact.length
    result = TSVTasks.clone_table(src)
    reordered = rhs.reorder(other_key.to_s, chosen, one2one: one2one, type: :double)
    reordered.key_field = source_name
    TSV.attach(result, reordered, match_key: source_name, other_key: :key, fields: chosen,
      one2one: one2one, complete: false, insitu: false)
    TSVTasks.canonical_render(result)
  end
  export :tsv_attach

  input :file, :path, 'TSV file', nil, required: true
  input :field, :string, 'Key or value field', nil, required: true
  input :target_format, :string, 'Target identifier format', nil, required: true
  input :identifiers, :path, 'Identifier mapping TSV (this path IS opened)', nil, required: true
  input :type, :string, 'Source table type: single, list, flat or double', nil
  input :key_field, :string, 'Key-field override', nil
  input :fields, :array, 'Value-field selection', nil
  input :one2one, :boolean, 'Use Scout one-to-one pairing when interpreting matched values', false
  extension :tsv
  task tsv_translate: :string do |file, field, target_format, identifiers, type, key_field, fields, one2one|
    TSVTasks.file!(file); TSVTasks.file!(identifiers); TSVTasks.type!(type)
    file = normalize(file, :read)
    identifiers = normalize(identifiers, :read)
    opts = {sep: "\t", sep2: '|', header_hash: '#', persist: false}
    opts[:type] = type.to_sym unless TSVTasks.optional(type)
    opts[:key_field] = key_field unless TSVTasks.optional(key_field)
    opts[:fields] = fields unless TSVTasks.optional(fields)
    table = TSV.open(file, opts)
    translated = TSV.translate(table, field.to_s, target_format.to_s,
      identifiers: identifiers, one2one: one2one, persist_index: false)
    TSVTasks.canonical_render(translated)
  end
  export :tsv_translate

  input :file, :path, 'TSV file', nil, required: true
  input :new_key_field, :string, 'New key field label persisted into the source (empty = keep)', nil
  input :rename_fields, :array, 'New value field labels persisted into the source, in order (empty = keep)', nil
  input :cast, :string, 'Persist parser cast metadata: to_i or to_f', nil
  input :identifiers, :path, 'Persist identifier mapping path metadata (recorded only; not opened)', nil
  input :namespace, :string, 'Persist TSV namespace metadata', nil
  input :new_type, :string, 'Persist a converted TSV type: single, list, flat, or double', nil
  input :key_field, :string, 'Source column to index by (input interpretation only)', nil
  input :fields, :array, 'Select value fields to project onto the persisted table', nil
  input :type, :string, 'Source table type: single, list, flat or double', nil
  input :sep, :string, 'Column separator', "\t"
  input :sep2, :string, 'Multi-value separator', '|'
  input :header_hash, :string, 'Header marker', '#'
  input :merge, :string, 'Duplicate-key merge: true, false, concat', nil
  input :one2one, :boolean, 'Use Scout one2one behavior', false
  extension :tsv
  task tsv_set_metadata: :json do |file, new_key_field, rename_fields, cast, identifiers, namespace, new_type, key_field, fields, type, sep, sep2, header_hash, merge, one2one|
    TSVTasks.file!(file); TSVTasks.type!(type); TSVTasks.type!(new_type); TSVTasks.cast!(cast)
    file = normalize(file, :read)
    raise ParameterException, 'tsv_set_metadata needs at least one metadata option (new_key_field, rename_fields, cast, identifiers, namespace or new_type)' if [new_key_field, rename_fields, cast, identifiers, namespace, new_type].all? { |v| TSVTasks.optional(v) }
    raise ParameterException, 'metadata mutation of a CSV source is unsupported; normalize it first with tsv_read' if TSVTasks.csv_source?(file, sep)
    open_options = TSVTasks.open_options(type: type, key_field: key_field, fields: fields, sep: sep, sep2: sep2, header_hash: header_hash, merge: merge, one2one: one2one)
    table = TSV.open(file, open_options)
    table = TSVTasks.rename_metadata!(table, key_name: new_key_field, field_names: rename_fields,
      namespace: namespace, identifiers: identifiers, cast: cast, type: new_type)
    # The projection implied by key_field/fields is baked into the persisted
    # table by design: this is the explicit mutation operation that inherited
    # tsv_info's old behavior.
    normalize(file, :write)
    TSVTasks.replace_source!(file, TSVTasks.render(table, sep: sep, sep2: sep2, header_hash: header_hash))
    {path: file, key_field: table.key_field, fields: table.fields || [], type: table.type,
     cast: table.cast, namespace: table.namespace, identifiers: table.identifiers,
     source_rows: table.keys.length, unique_keys: table.keys.length}
  end
  export :tsv_set_metadata

  input :file, :path, 'Prepared Scout TSV file', nil, required: true
  input :column, :string, 'Value field name, the exact current key field label, or the reserved alias "key" (default); prefix with @ to select a value field literally named "key"', 'key'
  input :direction, :select, 'Sort direction', 'ascending', select_options: %w[ascending descending]
  input :page, :integer, '1-based page number', 1
  input :page_size, :integer, "Rows per page; omitted uses the bounded default #{TSVTasks::DEFAULT_SORT_PAGE}. The page is never truncated silently: pass an explicit size for the whole table.", nil
  input :cast, :select, 'Cast sort values numerically', nil, select_options: %w[to_i to_f]
  input :just_keys, :boolean, 'Return only sorted keys instead of a TSV page', false
  task tsv_sort: :json do |file, column, direction, page, page_size, cast, just_keys|
    TSVTasks.file!(file)
    file = normalize(file, :read)
    raise ParameterException, 'direction must be ascending or descending' unless %w[ascending descending].include?(direction.to_s)
    raise ParameterException, 'page must be a positive integer' unless page.to_i.positive?
    raise ParameterException, 'page_size must be a positive integer' unless TSVTasks.optional(page_size) || page_size.to_i.positive?
    TSVTasks.cast!(cast)

    table = TSV.open(file, sep: "\t", sep2: '|', header_hash: '#', persist: false)
    selected = column.to_s
    resolved = if selected.empty?
                 :key
               else
                 TSVTasks.resolve_field(table, selected)
               end
    # Pass the RESOLVED field to TSV#page, never the caller's string. The
    # string form relies on page()'s internal coercion: a value field named
    # "key" (selected via @key) would be coerced to the :key alias and sort by
    # the row key — or crash traverse (fields["key"] on an Array) on
    # scout-gear 10.13.1. resolve_field yields :key or a value-field index.
    sort_field = resolved
    raise ParameterException, 'Sorting by named columns is unsupported for flat TSVs' if sort_field != :key && table.type.to_sym == :flat

    sorter = if !TSVTasks.optional(cast) && sort_field != :key
               proc do |_key, value|
                 # TSV#sort_by supplies the selected cell, which may be nested
                 # or multi-valued for list/double rows. Match TSV's ordinary
                 # field sort semantics by comparing the first value only.
                 value = value.first while value.is_a?(Array)
                 value.nil? ? 0 : value.public_send(cast.to_sym)
               end
             end
    per_page = TSVTasks.optional(page_size) ? TSVTasks::DEFAULT_SORT_PAGE : page_size.to_i
    page_keys = table.page(page.to_i, per_page, sort_field, true, direction.to_s == 'descending', &sorter) || []
    if just_keys
      {column: selected.empty? ? 'key' : selected, direction: direction.to_s,
       page: page.to_i, page_size: per_page, total_keys: table.keys.length,
       truncated: page_keys.length < table.keys.length, keys: page_keys}
    else
      result = TSV.setup({}, table.annotation_hash.reject { |name, _| name.to_sym == :filename })
      page_keys.each { |key| result[key] = TSVTasks.copy(table[key]) }
      {column: selected.empty? ? 'key' : selected, direction: direction.to_s,
       page: page.to_i, page_size: per_page, total_keys: table.keys.length,
       truncated: page_keys.length < table.keys.length,
       tsv: TSVTasks.canonical_render(result)}
    end
  end
  export :tsv_sort

end
