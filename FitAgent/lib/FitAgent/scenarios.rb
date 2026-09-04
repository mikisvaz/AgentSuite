require 'fileutils'
require 'digest'
require 'yaml'
require 'json'

module FitAgent
  # Deterministic scenario catalogue for the patch-tool improvement loop
  # (research/07 section 3; rubric expectations frozen per research/08 and
  # var/cortex/artifacts/verifications/patch-probe-matrix-v1.md).
  #
  # The catalogue is fully self-contained: fixtures are regenerated from code
  # with a recorded seed, never copied from the disposable probe tree under
  # tmp/patch_probes. Scenario outcome shapes mirror the frozen probe matrix:
  #
  #   F01..F08  functional, expect clean apply (exit 0, applied, strip 1)
  #   E01       stale context      -> controlled failure (exit 1, not applied)
  #   E02       ambiguous context  -> converter error ("Ambiguous")
  #   E03       stale @@ counts    -> lenient recompute, success
  #   E04       no trailing NL     -> success
  #   E05/E05b  add file (fresh / over existing target) -> success
  #   E06       delete file        -> success, file gone
  #
  # Each scenario directory layout (the runner contract of run_all.sh):
  #
  #   <set>/<SC>/scenario.yaml   id, class, description, file list
  #   <set>/<SC>/patch.txt       the patch handed to the agent under test
  #   <set>/<SC>/<fixtures>      pristine pre-state (also copied into work/)
  #   <set>/<SC>/work/           pristine work tree the agent patches into
  #   <set>/<SC>/expected/       authoritative after-state (byte-compare)
  #   <set>/<SC>/rubric.yaml     deterministic rubric (functional + message)
  #
  # plus <set>/manifest.json with per-scenario and set digests.
  module Scenarios
    VERSION = 'patch-v1'
    DEFAULT_SEED = 'fitagent-v1'

    SUCCESS_MESSAGE_RULES = {
      'tool' => 'patch', 'min_calls' => 1, 'max_calls' => 2,
      'expect' => { 'applied' => true, 'exit_status' => 0, 'used_strip' => 1 }
    }.freeze

    class << self
      # -- fixture helpers ---------------------------------------------------

      def numbered_lines(prefix, count, sep = ' ')
        (1..count).map { |n| "#{prefix}#{n}#{sep}payload-#{n}" }.join("\n") + "\n"
      end

      def canonical_diff(file, hunk)
        "--- a/#{file}\n+++ b/#{file}\n#{hunk}"
      end

      # -- scenario definitions ---------------------------------------------

      def f01
        notes = (1..10).map { |n| "note-#{n}" }.join("\n") + "\n"
        patch = canonical_diff('notes.txt', <<~DIFF)
          @@ -4,7 +4,7 @@
           note-4
           note-5
           note-6
          -note-7
          +note-seven
           note-8
           note-9
           note-10
        DIFF
        define('F01', 'functional',
               'Small text file, canonical unified diff, single-line change',
               { 'notes.txt' => notes }, patch,
               { 'notes.txt' => notes.sub("note-7\n", "note-seven\n") },
               { 'notes.txt' => 'match' })
      end

      def f02
        calc = <<~'RUBY'
          def add(a, b)
            a + b
          end

          def sub(a, b)
            a - b
          end

          def mul(a, b)
            a * b
          end
        RUBY
        patch = <<~'PATCH'
          *** Begin Patch
          *** Update File: calc.rb
          @@
          -def sub(a, b)
          -  a - b
          -end
          +def subtract(a, b)
          +  a - b
          +end
          *** End Patch
        PATCH
        define('F02', 'functional',
               'Small ruby file, ChatGPT-style block, multi-line rename',
               { 'calc.rb' => calc }, patch,
               { 'calc.rb' => calc.sub("def sub(a, b)", "def subtract(a, b)") },
               { 'calc.rb' => 'match' })
      end

      def f03
        tasks = <<~MD
          # Tasks

          - [ ] write intro
          - [ ] write body
          - [ ] write conclusion

          ## Notes

          remember to run the tests
        MD
        patch = <<~'PATCH'
          *** Begin Patch
          *** Update File: task.md
          @@
          -- [ ] write intro
          -- [ ] write body
          +- [x] write intro
          +- [x] write body
          *** End Patch
        PATCH
        define('F03', 'functional',
               'Markdown checklist, ChatGPT-style block, one hunk',
               { 'task.md' => tasks }, patch,
               { 'task.md' => tasks.sub("- [ ] write intro\n- [ ] write body\n",
                                        "- [x] write intro\n- [x] write body\n") },
               { 'task.md' => 'match' })
      end

      def f04
        parser = <<~'RUBY'
          class Parser
            def initialize(tokens)
              @tokens = tokens
            end

            def parse
              ast = []
              until @tokens.empty?
                ast << shift_token
              end
              ast
            end

            def shift_token
              @tokens.shift
            end
          end
        RUBY
        patch = <<~'PATCH'
          *** Begin Patch
          *** Update File: parser.rb
          @@
             def parse
               ast = []
               until @tokens.empty?
          -      ast << shift_token
          +      ast.push(shift_token)
               end
               ast
             end
          *** End Patch
        PATCH
        define('F04', 'functional',
               'Ruby file, ChatGPT-style block with context lines',
               { 'parser.rb' => parser }, patch,
               { 'parser.rb' => parser.sub("ast << shift_token", "ast.push(shift_token)") },
               { 'parser.rb' => 'match' })
      end

      def f05
        big = numbered_lines('entry-', 300, ' ')
        edited = big.sub("entry-250 payload-250\n", "entry-250 payload-EDITED\n")
        patch = canonical_diff('big.log', <<~DIFF)
          @@ -247,7 +247,7 @@
           entry-247 payload-247
           entry-248 payload-248
           entry-249 payload-249
          -entry-250 payload-250
          +entry-250 payload-EDITED
           entry-251 payload-251
           entry-252 payload-252
           entry-253 payload-253
        DIFF
        define('F05', 'functional',
               'Large file (300 lines), canonical diff, needle-in-haystack 1-line change',
               { 'big.log' => big }, patch,
               { 'big.log' => edited },
               { 'big.log' => 'match' })
      end

      def f06
        essay = <<~MD
          # On Patching

          Lorem ipsum dolor sit amet, consectetur adipiscing elit — sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat — Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

          ## Chapter Two

          The quick brown fox jumps over the lazy dog while twelve bankers forge quotes —pack my box with five dozen liquor jugs— and the five boxing wizards jump quickly.

          ## Coda

          Nothing to see here.
        MD
        old_line = "The quick brown fox jumps over the lazy dog while twelve bankers forge quotes —pack my box with five dozen liquor jugs— and the five boxing wizards jump quickly.\n"
        new_line = "The quick brown fox jumps over the lazy dog while five boxing wizards jump quickly —pack my box with five dozen liquor jugs.\n"
        patch = canonical_diff('essay.md', <<~DIFF)
          @@ -5,5 +5,5 @@
           ## Chapter Two

          -#{old_line.chomp}
          +#{new_line.chomp}

           ## Coda
        DIFF
        define('F06', 'functional',
               'Long unicode lines, canonical diff, one long line replaced',
               { 'essay.md' => essay }, patch,
               { 'essay.md' => essay.sub(old_line, new_line) },
               { 'essay.md' => 'match' })
      end

      def f07
        routes = <<~'RUBY'
          get '/old' do
            'old route'
          end
        RUBY
        expected = <<~'RUBY'
          get '/new' do
            'new route'
          end

          post '/submit' do
            'submitted'
          end
        RUBY
        patch = <<~'PATCH'
          *** Begin Patch
          *** Update File: routes.rb
          @@
          -get '/old' do
          -  'old route'
          -end
          +get '/new' do
          +  'new route'
          +end
          +
          +post '/submit' do
          +  'submitted'
          +end
          *** End Patch
        PATCH
        define('F07', 'functional',
               'Near-rewrite via ChatGPT-style full-content update block',
               { 'routes.rb' => routes }, patch,
               { 'routes.rb' => expected },
               { 'routes.rb' => 'match' })
      end

      def f08
        config = <<~YAML
          title: sample
          items:
            - one
            - two
        YAML
        fenced = "```diff\n" + canonical_diff('config.yml', <<~DIFF) + "```\n"
          @@ -1,4 +1,4 @@
           title: sample
           items:
          -  - one
          +  - ONE
             - two
        DIFF
        define('F08', 'functional',
               'Canonical diff quoted inside a markdown code fence',
               { 'config.yml' => config }, fenced,
               { 'config.yml' => config.sub("  - one\n", "  - ONE\n") },
               { 'config.yml' => 'match' })
      end

      def e01
        readme = "# Probe\ndesc one\ndesc two\ndesc three\ndesc four\n"
        patch = canonical_diff('readme.txt', <<~DIFF)
          @@ -1,5 +1,5 @@
           # Probe
           desc one
          -desc WRONG LINE
          +desc right line
           desc two
           desc three
        DIFF
        define('E01', 'error',
               'Stale context line: hunk must FAIL, file unchanged',
               { 'readme.txt' => readme }, patch,
               { 'readme.txt' => readme },
               { 'readme.txt' => 'match' },
               tool: 'patch', min_calls: 1, max_calls: 3,
               expect: { 'applied' => false, 'exit_status' => 1 })
      end

      def e02
        dup = "alpha\nbeta\ngamma\ndelta\nalpha\nbeta\ngamma\n"
        patch = <<~'PATCH'
          *** Begin Patch
          *** Update File: dup.txt
          @@
          -alpha
          -beta
          +ALPHA
          +BETA
          *** End Patch
        PATCH
        define('E02', 'error',
               'Ambiguous context (duplicate blocks): converter raises before patch runs; ' \
               'the in-chat tool output carries the exception text',
               { 'dup.txt' => dup }, patch,
               { 'dup.txt' => dup },
               { 'dup.txt' => 'match' },
               tool: 'patch', min_calls: 1, max_calls: 3,
               expect: { 'output_contains' => ['Ambiguous'] })
      end

      def e03
        list = "a\nb\nc\nd\ne\n"
        patch = <<~'PATCH'
          *** Begin Patch
          *** Update File: list.txt
          @@ -1,2 +1,2 @@
           a
          -b
          -c
          -d
          +B
          +C
          +D
           e
          *** End Patch
        PATCH
        define('E03', 'error',
               'Stale @@ header counts: converter recomputes them, apply succeeds (lenient)',
               { 'list.txt' => list }, patch,
               { 'list.txt' => "a\nB\nC\nD\ne\n" },
               { 'list.txt' => 'match' })
      end

      def e04
        poem = "roses are red\nviolets are blue"
        expected = "roses are red\nviolets are BLUE"
        patch = canonical_diff('poem.txt', <<~DIFF)
          @@ -1,2 +1,2 @@
           roses are red
          -violets are blue
          \\ No newline at end of file
          +violets are BLUE
          \\ No newline at end of file
        DIFF
        define('E04', 'error',
               'File without trailing newline: canonical diff with no-newline markers',
               { 'poem.txt' => poem }, patch,
               { 'poem.txt' => expected },
               { 'poem.txt' => 'match' })
      end

      def e05
        patch = <<~'PATCH'
          *** Begin Patch
          *** Add File: created.txt
          created by patch
          second line
          *** End Patch
        PATCH
        define('E05', 'error',
               'Add-file patch over a fresh target: file created',
               {}, patch,
               { 'created.txt' => "created by patch\nsecond line\n" },
               { 'created.txt' => 'match' })
      end

      def e05b
        patch = <<~'PATCH'
          *** Begin Patch
          *** Add File: created.txt
          created by patch
          second line
          *** End Patch
        PATCH
        define('E05b', 'error',
               'Add-file patch over a pre-existing target: content is replaced',
               { 'created.txt' => "pre-existing content\nthat should NOT be overwritten\n" },
               patch,
               { 'created.txt' => "created by patch\nsecond line\n" },
               { 'created.txt' => 'match' })
      end

      def e06
        patch = <<~'PATCH'
          *** Begin Patch
          *** Delete File: old_file.txt
          *** End Patch
        PATCH
        define('E06', 'error',
               'Delete-file patch: target removed from the work tree',
               { 'old_file.txt' => "obsolete content\n" }, patch,
               {},
               { 'old_file.txt' => 'absent' })
      end

      def definitions
        [f01, f02, f03, f04, f05, f06, f07, f08,
         e01, e02, e03, e04, e05, e05b, e06]
      end

      def define(id, klass, description, files, patch, expected, expect_files,
                 tool: nil, min_calls: nil, max_calls: nil, expect: nil)
        message = { 'tool' => tool || 'patch',
                    'min_calls' => min_calls || SUCCESS_MESSAGE_RULES['min_calls'],
                    'max_calls' => max_calls || SUCCESS_MESSAGE_RULES['max_calls'],
                    'expect' => expect || SUCCESS_MESSAGE_RULES['expect'].dup }
        { 'id' => id, 'class' => klass, 'description' => description,
          'files' => files, 'patch' => patch, 'expected' => expected,
          'expect_files' => expect_files, 'message_rules' => message }
      end

      # -- materialization ---------------------------------------------------

      def scenario_ids(set_dir)
        Dir.glob(File.join(set_dir.to_s, '*')).select do |d|
          File.directory?(d) && File.file?(File.join(d, 'rubric.yaml'))
        end.map { |d| File.basename(d) }.sort
      end

      def materialize(set_dir, ids: nil, seed: DEFAULT_SEED)
        set_dir = set_dir.to_s
        known = definitions.map { |d| d['id'] }
        selected = Array(ids).empty? ? known : Array(ids).map(&:to_s)
        unknown = selected - known
        raise ArgumentError, "unknown scenarios #{unknown.inspect} (known: #{known.inspect})" unless unknown.empty?

        FileUtils.mkdir_p set_dir
        entries = []
        definitions.each do |sc|
          next unless selected.include?(sc['id'])
          entries << write_scenario(set_dir, sc)
        end

        manifest = {
          'set' => set_dir, 'name' => File.basename(set_dir.sub(%r{/$}, '')),
          'version' => VERSION, 'seed' => seed,
          'scenarios' => entries.sort_by { |e| e['id'] },
          'set_digest' => Digest::MD5.hexdigest(entries.map { |e| "#{e['id']}:#{e['digest']}" }.sort.join("\n"))
        }
        File.open(File.join(set_dir, 'manifest.json'), 'w') { |f| f.write(JSON.pretty_generate(manifest) + "\n") }
        manifest
      end

      def write_scenario(set_dir, sc)
        dir = File.join(set_dir, sc['id'])
        FileUtils.rm_rf dir
        FileUtils.mkdir_p File.join(dir, 'expected')
        FileUtils.mkdir_p File.join(dir, 'work')

        sc['files'].each do |rel, content|
          write_file(File.join(dir, rel), content)
          write_file(File.join(dir, 'work', rel), content)
        end
        sc['expected'].each do |rel, content|
          write_file(File.join(dir, 'expected', rel), content)
        end
        write_file(File.join(dir, 'patch.txt'), sc['patch'])

        info = { 'id' => sc['id'], 'class' => sc['class'],
                 'description' => sc['description'], 'patch' => 'patch.txt',
                 'files' => sc['files'].keys.sort }
        write_file(File.join(dir, 'scenario.yaml'), YAML.dump(info))

        rubric = {
          'scenario' => sc['id'], 'class' => sc['class'],
          'description' => sc['description'], 'patch' => 'patch.txt',
          'functional' => { 'expect_files' => sc['expect_files'],
                            'reject_residue' => true },
          'message_rules' => sc['message_rules']
        }
        write_file(File.join(dir, 'rubric.yaml'), YAML.dump(rubric))

        { 'id' => sc['id'], 'class' => sc['class'], 'digest' => digest_tree(dir) }
      end

      def write_file(path, content)
        FileUtils.mkdir_p File.dirname(path)
        File.open(path, 'wb') { |f| f.write(content) }
      end

      def digest_tree(dir)
        files = Dir.glob(File.join(dir, '**', '*')).select { |f| File.file?(f) }
        rels = files.map { |f| f.sub(%r{^#{Regexp.escape(dir)}/?}, '') }.sort
        Digest::MD5.hexdigest(rels.map do |rel|
          "#{rel}:#{Digest::MD5.hexdigest(File.binread(File.join(dir, rel)))}"
        end.join("\n"))
      end
    end
  end
end
