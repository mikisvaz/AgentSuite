module Workspace

  def self.get_allowed_paths(type)
    LLM::Sandbox.grant_paths(type, scope: 'Workspace')
  end

  @root = Dir.pwd
  singleton_class.attr_accessor :root

  def self.allowed_paths
    LLM::Sandbox.writable_grants(scope: 'Workspace')
  end

  def self.allowed_read_paths
    LLM::Sandbox.readable_grants(scope: 'Workspace')
  end

  # Authorization goes through the shared LLM::Sandbox containment policy.
  # The original path spelling is preserved for all filesystem operations;
  # Decision#canonical_path is an authorization/diagnostic value only.
  #
  # ScoutCoder: LLM::Sandbox.resolve_path treats '~...' as a relative path
  # (it does not expand the home directory), so '~' spellings must be
  # expanded by the caller before authorize_path to keep home grants working.
  helper :normalize do |path, type=:read|
    path = '.' if path == '' || TrueClass === path

    path = path.find(:current) if Path === path && ! path.located?
    path = File.expand_path(path) if path.start_with?('~')

    mode = type.to_s == 'read' ? :read : :write

    decision = LLM::Sandbox.authorize_path(path,
                                           root: Workspace.root.to_s,
                                           writable_paths: Workspace.allowed_paths.map(&:to_s),
                                           read_paths: Workspace.allowed_read_paths.map(&:to_s),
                                           mode: mode,
                                           base_path: Dir.pwd)

    unless decision.allowed
      if mode == :read
        raise SandboxAccessViolation, "Path #{path} not read allowed. Allowed paths:\n    #{describe_allowed_paths}"
      else
        raise SandboxAccessViolation, "Path #{path} not write allowed. Allowed paths:\n    #{describe_allowed_paths}"
      end
    end

    path
  end


  # -------------------------------------------------------------------------
  # Sandbox introspection. The helpers below describe the effective
  # filesystem permissions of the workflow: which paths the Ruby-level
  # tasks (read/write/delete/search/list_directory) accept, where those
  # paths come from, and how they are mounted inside the bwrap sandbox
  # used by the exec tasks (bash/ruby/python/r). They are strictly
  # read-only.
  # -------------------------------------------------------------------------

  helper :classify_path do |path|
    info = {path: path}
    begin
      info[:symlink] = File.symlink?(path)
    rescue
      info[:symlink] = false
    end
    begin
      info[:readlink] = File.readlink(path) if info[:symlink]
    rescue
      info[:readlink] = nil
    end
    begin
      info[:realpath] = File.realpath(path)
    rescue Errno::ENOENT, Errno::ENOTDIR, ArgumentError
      info[:realpath] = nil
    end
    info[:exists] = File.exist?(path)
    info[:type] = if info[:symlink]
                    'symlink'
                  elsif File.directory?(path)
                    'directory'
                  elsif File.file?(path)
                    'file'
                  else
                    'missing'
                  end
    info
  end

  # One line per allowlist entry, annotated with read/write semantics, so
  # denial messages are self-explanatory.
  helper :describe_allowed_paths do
    LLM::Sandbox.describe_grants(scope: 'Workspace',
                                 root: Workspace.root.to_s,
                                 hint: "Run task 'sandbox_paths' for details (file/dir, symlinks, mounts)")
  end

  # Which allowlist source granted a given expanded path.
  helper :path_origin do |path|
    LLM::Sandbox.grant_origin(path, scope: 'Workspace', root: Workspace.root.to_s)
  end

  # Reproduce, without executing anything, the mount plan that
  # sandbox_run builds for the exec tasks. Follows the same composition
  # order as sandbox_run: bwrap_* lists, allowed lists, and always root
  # as writable. Network and runtime additions are noted as limits.
  helper :sandbox_mount_plan do
    read_paths = Workspace.allowed_read_paths.dup
    bwrap_read = Workspace.get_allowed_paths(:bwrap_read_paths)
    read_paths += bwrap_read if bwrap_read && !bwrap_read.empty?

    writable_paths = Workspace.allowed_paths.dup
    bwrap_writable = Workspace.get_allowed_paths(:bwrap_paths)
    writable_paths += bwrap_writable if bwrap_writable && !bwrap_writable.empty?

    # The exec sandbox always grants write access to the workflow root.
    root = Workspace.root
    root = root.find if Path === root
    writable_paths << root.to_s if root && !root.to_s.empty?

    read_paths = read_paths.flatten.compact.uniq
    writable_paths = writable_paths.flatten.compact.uniq

    plan_mounts(read_paths, writable_paths)
  end

  helper :realized_mounts do
    return nil unless File.readable?('/proc/mounts')
    base = %w(/ /proc /dev /sys)
    File.readlines('/proc/mounts').collect do |line|
      parts = line.split(/\s+/)
      next if base.include?(parts[1])
      {device: parts[0], mountpoint: parts[1], filesystem: parts[2], options: parts[3]}
    end.compact
  end

  input :path, :path, 'Writable destination path for the complete contents', nil, required: true
  input :content, :text, 'Content to write into the file', nil, required: true
  task :write => :string do |file,content|
    raise ParameterException, "File is nil or empty: #{path}" if path.nil? || path.empty?
    file = normalize file, :write
    raise ParameterException, "File is a directory: #{file}" if Open.directory?(file)
    Open.write file, content
    "success writing to #{file}"
  end

  input :path, :path, 'Path to the file to read', nil, required: true
  input :limit, :integer, 'Maximum number of lines to return from chosen end of the file'
  input :chars, :integer, 'Character window from the selected end, applied after line selection'
  input :file_end, :select, 'Side of file to read', :head, select_options: %w(head tail)
  input :start, :integer, 'Zero-based line offset for head with a positive line limit. Use zero for the last group with tail.', 0
  task :read => :text do |file, limit, chars, file_end, start|
    file = normalize file

    raise ParameterException, "File not found #{file}" unless Open.exists?(file)
    raise ParameterException, 'File is really a directory, can not read' if Open.directory?(file)

    begin
      # no limit -> read full file (same behaviour as before)
      unless (limit && limit.to_i > 0) || (chars && chars.to_i > 0)
        next Open.read(file)
      end

      limit = limit.to_i
      raise ParameterException, "Wrong limit: #{Log.fingerprint limit}" if limit < 0

      chars = chars.to_i
      raise ParameterException, "Wrong chars limit: #{Log.fingerprint chars}" if chars < 0

      start = (start || 0).to_i
      raise ParameterException, "Wrong start: #{Log.fingerprint start}" if start < 0

      if limit > 0
        res = case file_end.to_s
              when '', 'head'
                # Read from the start (or from start offset) without loading whole file
                lines = []
                File.open(file, 'rb') do |f|
                  f.each_line.with_index do |ln, idx|
                    next if idx < start
                    lines << (ln.chomp)
                    break if limit > 0 && lines.length >= limit
                  end
                end
                lines.join("\n")
              when 'tail'
                # Efficiently collect lines from the end without loading the whole file.
                # We need limit + start lines from the end, then drop the first `start`
                needed = limit + start
                buffer = ''
                File.open(file, 'rb') do |f|
                  f.seek(0, IO::SEEK_END)
                  pos = f.pos
                  # read backwards in blocks until we have enough newlines or we reached start
                  while pos > 0 && buffer.count("\n") <= needed
                    read_size = [pos, 8192].min
                    pos -= read_size
                    f.seek(pos, IO::SEEK_SET)
                    buffer = f.read(read_size) + buffer
                  end
                end

                # Split into lines. If the file ends with newline, split will give last element '' — using split("\n") gives predictable behaviour.
                arr = buffer.split("\n")
                # choose the last `needed` lines (or fewer if file smaller)
                start_index = [arr.length - needed, 0].max
                selected = arr[start_index, needed] || []
                # drop `start` lines from the front of the selected portion, then take `limit`
                result = (selected[start, limit] || [])

                result.join("\n")
              else
                raise ParameterException, "Unknown file_end must be head or tail: #{Log.fingerprint file_end}"
              end
      else
        res = Open.read(file)
      end

      if chars && chars.to_i > 0
        if file_end == 'tail'
          res = res[-(chars+1)..-1]
        else
          res = res[0..chars-1]
        end
      end

    rescue SystemCallError
      raise ParameterException, "Could not read file: #{$!.message}"
    end
    res
  end

  input :directory, :path, 'Readable directory path to enumerate', nil, required: true
  input :recursive, :boolean, 'List recursively', true
  input :stats, :boolean, 'Request size and modification time for listed files', false
  task :list_directory => :json do |directory,recursive,stats|
    raise ParameterException, "Directory is a regular expression" if Regexp === directory
    directory = normalize directory
    raise ParameterException, "Directory not found: #{directory}" unless Open.exists?(directory)
    raise ParameterException, "Not a directory: #{directory}" unless Open.directory?(directory)
    files = if recursive
              Path.setup(directory).glob('**/*')
            else
              Path.setup(directory).glob('*')
            end

    info = {files: [], directories: []}

    files.each do |file|
      if file.directory?
        info[:directories] << file.find
      else
        info[:files] << file.find
      end
    end

    if stats && Open.exists?(file)
      info[:stats] = {}
      info[:files].each do |file|
        info[:stats][file] = {
          size: Open.size(file),
          mtime: Open.mtime(file)
        }

      end
    end

    info
  end

  input :file, :path, 'Readable file or directory path', nil, required: true
  task :file_stats => :json do |file,root|
    normalize file
    raise ParameterException, "File not found: #{file}" unless Open.exists?(file)
    file = Path.setup(file)
    stats = {}
    stats[:type] = file.directory? ? :directory : :file
    if ! file.directory?
      stats[:binary] = false
      stats[:size] = Open.size(file)
      stats[:lines] = Open.read(file).split("\n").length
      stats[:mtime] = Open.mtime(file)
    end
    stats
  end

  export_exec :list_directory, :write, :read, :file_stats

  task :sandbox_paths => :json do
    writable = [Workspace.root, Workspace.allowed_paths].flatten.compact.uniq
    readable = Workspace.allowed_read_paths.flatten.compact.uniq

    classify = lambda do |paths|
      paths.collect do |p|
        expanded = File.expand_path(p.to_s)
        classify_path(expanded).merge(origin: path_origin(expanded))
      end
    end

    bwrap = begin
              find_bwrap
            rescue
              nil
            end

    {
      root: Workspace.root.to_s,
      pwd: ENV['PWD'] || Dir.pwd,
      pwd_realpath: File.realpath(Dir.pwd),
      home: ENV['HOME'],
      bwrap: bwrap.nil? ? nil : bwrap.to_s,
      note: "File tasks check their input paths against Scout-AI grants. Reads accept writable and read grants. Writes require a writable location. For commands, mounts shows the base bwrap plan with host source, child destination and mode. Command-specific mounts are added at launch. realized_mounts describes the reporting process.",
      writable: classify.call(writable),
      readable: classify.call(readable),
      mounts: sandbox_mount_plan.collect do |m|
        {source: m.source, destination: m.destination, mode: m.mode.to_s,
         requested_path: m.requested_path, redirect: m.destination != m.requested_path}
      end,
      realized_mounts: realized_mounts,
    }
  end


  task :pwd => :string do
    ENV['PWD'] || Dir.pwd
  end

  # Delete task
  input :file, :path, 'File or directory to delete', nil, required: true
  task :delete => :string do |file|
    file = normalize file, :write
    raise ParameterException, "File not found: #{file}" unless Open.exists?(file)
    raise ParameterException, "Root path cannot be deleted" if File.expand_path(file) == File.expand_path(Workspace.root)

    if Open.directory?(file)
      Open.rm_rf(file)
      "deleted directory #{file}"
    else
      Open.rm(file)
      "deleted file #{file}"
    end
  end

  # Copy task
  input :source, :path, 'Readable source path', nil, required: true
  input :target, :path, 'Writable destination path', nil, required: true
  task :copy => :string do |source,target|
    source = normalize source, :read
    target = normalize target, :write
    raise ParameterException, "Source file not found: #{source}" unless Open.exists?(source)
    raise ParameterException, "Source file same as target file #{source}" if source == target
    raise ParameterException, "Root path cannot be deleted" if File.expand_path(file) == File.expand_path(Workspace.root)

    Open.cp source, target
  end

  # Search for files within a directory whose content matches a query string.
  # The search is performed recursively on the supplied path (which must be a
  # subpath of Workspace.root).
  input :path, :path, 'Root directory to search', nil, required: true
  input :query, :string, 'String to search for in file contents', nil, required: true
  input :max_results, :integer, 'Maximum number of results to return', 10
  input :max_files, :integer, 'Maximum glob entries allowed, including directories (default 200)', 200
  task :search => :array do |path, query, max_results, max_files|
    path = normalize path
    raise ParameterException, "Directory not found: #{path}" unless Open.exists?(path)
    raise ParameterException, "Not a directory: #{path}" unless Open.directory?(path)
    raise ParameterException, "Empty query string" if query.nil? || query.empty?
    results = []
    max_results = max_results.to_i
    max_results = Float::INFINITY if max_results <= 0
    files = Path.setup(path).glob('**/*')

    raise ParameterException, "Too many files #{files.length} (maximum #{max_files})" if files.length > max_files

    TSV.traverse files, bar: self.progress_bar("Searching files") do |file|
      break if results.size >= max_results
      next if file.directory?
      next if Open.compressed?(file)
      begin
        content = file.read
      rescue
        next
      end
      next unless content.include?(query)
      results << file.relative_to(path)
    end
    results
  end

  export_exec :list_directory, :write, :read, :file_stats, :pwd, :copy, :delete, :search, :sandbox_paths
end
