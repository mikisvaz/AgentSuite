require 'scout-ai'
require 'fileutils'
require 'json'

# v9 delivery probe (step 5a): parse FRESH agent contexts for the 7 roles
# touched by v9 and record the actual resolved provisioning surfaces —
# tools, kb/mcp, introduce, imports (including nested import expansion),
# path_kind, socialize. Same pattern as tmp/v8-step3/parse_probe.rb but the
# matrix extraction is complete, not just a leak scan.
repo = '/bulk/mvazque2/git/AgentSuite'
scratch = File.join(repo, 'tmp/v9-probes/chats')
FileUtils.rm_rf scratch
FileUtils.mkdir_p File.join(scratch, 'Agent/doctrines')
FileUtils.cp File.join(repo, 'doctrine'), File.join(scratch, 'Agent/doctrine')
FileUtils.cp File.join(repo, 'society'), File.join(scratch, 'Agent/society')
FileUtils.cp File.join(repo, 'scout'), File.join(scratch, 'Agent/scout')
Dir.glob(File.join(repo, 'doctrines/*')).each { |d| FileUtils.cp d, File.join(scratch, 'Agent/doctrines', File.basename(d)) }

ROLES = %w[Manager Research Analyst ScientificLead Critic Worker ScoutCoder]

out = {}
ROLES.each do |role|
  src = File.join(repo, role, 'start_chat')
  dst = File.join(scratch, role)
  FileUtils.cp src, dst
  raw = File.read(dst)
  msgs = Misc.in_dir(scratch) do
    m = Chat.indiferent(Chat.parse(raw))
    Chat.imports m, dst, scratch
  end

  counts = Hash.new(0)
  msgs.each { |m| counts[m[:role]] += 1 }

  tools = msgs.select { |m| m[:role].to_s == 'tool' }.map { |m| m[:content].to_s.strip }
  introduces = msgs.select { |m| m[:role].to_s == 'introduce' }.map { |m| m[:content].to_s.strip.split("\n").first }
  kbs = msgs.select { |m| m[:role].to_s == 'kb' }.map { |m| m[:content].to_s.strip }
  mcps = msgs.select { |m| m[:role].to_s == 'mcp' }.map { |m| m[:content].to_s.strip }
  path_kinds = msgs.select { |m| m[:role].to_s == 'path_kind' }.map { |m| m[:content].to_s.strip }
  socializes = msgs.select { |m| m[:role].to_s == 'socialize' }.map { |m| m[:content].to_s.strip }
  exec_tasks = msgs.select { |m| m[:role].to_s == 'exec_task' }.map { |m| m[:content].to_s.strip }

  leftover = msgs.count { |m| m[:role].to_s == 'import' }
  unknown = msgs.reject { |m| %w[system user tool introduce import path_kind socialize exec_task kb mcp assistant meta].include?(m[:role].to_s) }

  # nested import provenance: which import lines from the raw file survived (role 'system' with import provenance)
  import_files = msgs.select { |m| m[:role].to_s == 'system' && m[:origin].to_s.include?('/Agent/') }.map { |m| m[:origin].to_s.sub(scratch + '/', '') }

  out[role] = {
    counts: counts,
    tools: tools,
    introduces: introduces,
    kbs: kbs,
    mcps: mcps,
    path_kinds: path_kinds,
    socializes: socializes,
    exec_tasks: exec_tasks,
    leftover_imports: leftover,
    unknown_roles: unknown.map { |m| m[:role] }.uniq,
    import_files: import_files.uniq.sort
  }
end

File.write(File.join(repo, 'tmp/v9-probes', 'parse_probe_output.json'), JSON.pretty_generate(out))

out.each do |role, d|
  puts "== #{role}"
  puts "   roles: #{d[:counts].sort_by { |k, v| [-v, k.to_s] }.map { |k, v| "#{k}=#{v}" }.join(' ')}"
  puts "   tools(#{d[:tools].length}): #{d[:tools].join(' | ')}"
  puts "   introduces(#{d[:introduces].length}): #{d[:introduces].join(' | ')}"
  puts "   kb: #{d[:kbs].inspect} mcp: #{d[:mcps].inspect} path_kind: #{d[:path_kinds].inspect} socialize: #{d[:socializes].inspect} exec_task: #{d[:exec_tasks].inspect}"
  puts "   import_files: #{d[:import_files].inspect}"
  puts "   leftover_imports=#{d[:leftover_imports]} unknown=#{d[:unknown_roles].inspect}"
end
