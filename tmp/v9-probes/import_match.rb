require 'scout-ai'
require 'fileutils'
require 'json'

# v9 delivery probe, part 2: import-resolution matrix (role | import surface).
# Chat.parse consumes the leading "system:" header and un-escapes escaped
# directive markers, so normalization applies the same transform to the file
# side: strip "system:" header, strip leading "\" before "word:" line starts,
# collapse whitespace.
repo = '/bulk/mvazque2/git/AgentSuite'
scratch = File.join(repo, 'tmp/v9-probes/chats')

norm = lambda do |s|
  s.to_s.sub(/\Asystem:\s*/, '').gsub(/^\\(?=\w+:\s)/, '').gsub(/\s+/, ' ').strip
end

sources = [[ 'doctrine', File.join(repo, 'doctrine') ],
           [ 'society', File.join(repo, 'society') ],
           [ 'scout', File.join(repo, 'scout') ]]
Dir.glob(File.join(repo, 'doctrines/*')).each do |d|
  sources << [ "doctrines/#{File.basename(d)}", d ]
end
source_norm = sources.map { |name, p| [name, norm.call(File.read(p))] }

%w[Manager Research Analyst ScientificLead Critic Worker ScoutCoder].each do |role|
  dst = File.join(scratch, role)
  raw = File.read(dst)
  msgs = Misc.in_dir(scratch) do
    m = Chat.indiferent(Chat.parse(raw))
    Chat.imports m, dst, scratch
  end
  declared = raw.lines.grep(/^import: /).map { |l| l.sub('import: ', '').strip.sub('Agent/', '') }
  resolved = msgs.map do |m|
    hit = source_norm.find { |_name, content| content == norm.call(m[:content]) }
    hit ? hit[0] : nil
  end.compact
  missing = declared.sort - resolved.sort
  extra = resolved.sort - declared.sort
  ok = missing.empty? && extra.empty?
  puts "== #{role}: import_match=#{ok ? 'PASS' : 'FAIL'} declared=#{declared.length} resolved_imports=#{resolved.length}"
  missing.each { |m| puts "   MISSING: #{m}" }
  extra.each { |m| puts "   EXTRA: #{m}" }
end
