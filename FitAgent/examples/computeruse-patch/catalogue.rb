# Example FitAgent target: the ComputerUse patch workflow.
#
# Catalogue contents moved VERBATIM from lib/FitAgent/scenarios.rb (the
# pre-decoupling round) so the materialized fixture bytes — and therefore
# the frozen manifest digests — are unchanged. Do not reformat the strings.
#
# Expected digests (patch-v2 seed fitagent-v1), asserted by
# test/FitAgent/tasks/test_target_digests.rb:
#   C01 744e1796f196c692420321fa400f51e8
#   C02 f6f9af520ff44eab4e111662a0fb42d4
#   E01 6c0c8a4f90097c59eafdd08b4d40163c
#   E02 299884b7cff5148df87161ad5ef7e9d5
#   E03 e2797829f80449b8b6c8043fa693027d
#   E04 81e670ea4e8c98fa36aea92d2e988bae
#   E05 848ee96f964e4e6615daa1e1ce2d452f
#   E05b 296533c0a9b633ef78ed7af97d540f93
#   E06 7fe19c2b6d9ab8fb81345d2526c92f01
#   F01 e9a95a8b4b49a2e5e84c9377eedf9e3d
#   F02 3062228bcf1a0657ea48cf98d8d40598
#   F03 5442750af135f760cfac8be20d07f499
#   F04 3fec543e761f0cbff0020cfc62348338
#   F05 ea3c30fe0de0edf3ed941b06a0991b40
#   F06 8651cda4edfddc7220bf160072ea2c3f
#   F07 75dc204fb583f9c3c7a0fa0d0ae1f316
#   F08 640484b0f8093d76ec671159eb80b964
#   SET 4942cacdda221373327b296526c4155f

version 'patch-v2'

# -- functional: clean applies --------------------------------------------

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

# -- error scenarios ------------------------------------------------------

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
         expect: { 'applied' => false,
                   'output_contains' => ['FAILED'] })
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

# -- contrived traps (C-series) --------------------------------------------

def c01
  calc = <<-'RUBY'
          def add(a, b)
            a + b
          end

          def scale(v, k)
            v * k
          end

          def label(v)
            "value=#{v}"
          end

          def combine(xs)
            add(xs[0], xs[1]) * scale(xs[2], 2)
          end

          out = label(add(combine([1, 2, 3]), add(4, 5)))
          puts out
  RUBY
  expected = calc.gsub('add(', 'plus(')
  material = <<-'TEXT'
          Please rename the method `add` to `plus` throughout `calc.rb`.

          ```ruby
          def plus(a, b)
            a + b
          end
          ...
          ```

          (replace the definition and every call site; keep everything else)
  TEXT
  define('C01', 'contrived',
         'Fragment with ellipses: rename add->plus at the definition and every ' \
         'call site; other content byte-identical; no fences/ellipses/prose in the file',
         { 'calc.rb' => calc }, material,
         { 'calc.rb' => expected },
         { 'calc.rb' => 'match' },
         tool: 'patch', min_calls: 0, max_calls: 2, expect: {},
         max_total_calls: 8)
end

def c02
  list = "alpha\nbeta\ngamma\ndelta\nepsilon\nzeta\neta\n"
  # Plausible hunk: counts and start are self-consistent, but one
  # MIDDLE context line is misspelled (`epsiln`) -> GNU patch refuses
  # at every -p level (Hunk #1 FAILED; too many context lines differ
  # for fuzz), and the tree must stay pristine. NB a wrong line at the
  # EDGE of the hunk (`theta` vs `zeta`) IS fuzz-tolerated and applies
  # — live-verified in results/contrived-baseline; do not reintroduce.
  patch = canonical_diff('list.txt', <<~DIFF)
    @@ -2,6 +2,6 @@
     beta
     gamma
    -delta
    +DELTA
     epsiln
     zeta
     eta
  DIFF
  define('C02', 'contrived',
         'Stale-failure etiquette: subtly stale context (one wrong middle context ' \
         'line) must be refused; tree stays pristine; no rescue writes/bash after ' \
         'the failed patch',
         { 'list.txt' => list }, patch,
         { 'list.txt' => list },
         { 'list.txt' => 'match' },
         tool: 'patch', min_calls: 1, max_calls: 2,
         # FAILED alone is too weak: under bwrap the sandboxed patch
         # run loses GNU patch's own message, so the payload only
         # carries bwrap's 'error status 1'. 'Hunk #1 FAILED' covers
         # the un-sandboxed wording; live-verified both ways.
         expect: { 'applied' => false,
                   'output_contains' => ['FAILED', 'Hunk #1 FAILED'] },
         max_total_calls: 6,
         forbid_after_failed: %w[write bash python ruby r copy delete])
end

def definitions
  [f01, f02, f03, f04, f05, f06, f07, f08,
   e01, e02, e03, e04, e05, e05b, e06,
   c01, c02]
end
