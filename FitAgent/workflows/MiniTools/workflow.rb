# Portable minimal tool workflow for FitAgent sandboxes.
#
# FitAgent#use_case runs the agent under test inside an isolated sandbox
# directory. Full tool workflows (ComputerUse & friends) are not always
# visible from inside that sandbox (checkout layout, bwrap mounts, offline
# autoinstall), which used to leave agents with zero callable tools.
#
# MiniTools ships with FitAgent, is auto-linked into every use_case sandbox,
# and provides the small set of execution primitives an agent under test
# actually needs: shell, read, write, list. Tasks execute as plain child
# processes of the agent process (no nested sandboxing), so they work
# wherever the agent process itself can run.
module MiniTools
  extend Workflow

  desc "Run a shell command in the current working directory and return its exit status, stdout and stderr"
  input :cmd, :string, "Shell command to execute (runs via bash -lc, 120s cap)", nil, required: true
  task :sh => :string do |cmd|
    require 'open3'
    require 'timeout'
    begin
      out, err, status = Timeout.timeout(120) do
        Open3.capture3("bash", "-lc", cmd)
      end
      "exit=#{status.exitstatus}\n--stdout--\n#{out}\n--stderr--\n#{err}"
    rescue Timeout::Error
      "exit=timeout\n--stdout--\n--stderr--\ncommand exceeded 120s: #{cmd}"
    end
  end

  desc "Read a text file and return its contents"
  input :path, :string, "Path of the file to read (must be a short single-line file path, not the file body)", nil, required: true
  task :read_file => :string do |path|
    # Guard against models that paste the file body into the path argument:
    # a multi-line or very long "path" is never a real path.
    if path.nil? || path.to_s.lines.count > 1 || path.to_s.length > 4096
      raise ParameterException, "read_file takes one argument: the file path (a short single-line path). Got #{path.to_s.length} chars / #{path.to_s.lines.count} lines. To read a file call read_file with its path only."
    end
    raise "File not found: #{path}" unless File.file?(path)
    File.read(path)
  end

  desc "Write a text file, creating parent directories as needed (creates or overwrites)"
  input :path, :string, "Path of the file to write (a short single-line path)", nil, required: true
  input :content, :text, "Full content to write", nil, required: true
  task :write_file => :string do |path, content|
    # Guard against models that pass the file body as the path.
    if path.nil? || path.to_s.lines.count > 1 || path.to_s.length > 4096
      raise ParameterException, "write_file takes two arguments: path then content. The path must be a short single-line path. Got path of #{path.to_s.length} chars / #{path.to_s.lines.count} lines."
    end
    FileUtils.mkdir_p(File.dirname(File.expand_path(path)))
    File.write(path, content)
    "wrote #{content.length} bytes to #{path}"
  end

  desc "List a directory, one entry per line, directories suffixed with /"
  input :path, :string, "Directory to list", "."
  task :list_dir => :string do |path|
    path = "." if path.nil? || path.to_s.strip.empty?
    raise "Not a directory: #{path}" unless File.directory?(path)
    Dir.entries(path).reject { |e| e == '.' || e == '..' }.sort.map do |e|
      File.directory?(File.join(path, e)) ? "#{e}/" : e
    end.join("\n")
  end
end
