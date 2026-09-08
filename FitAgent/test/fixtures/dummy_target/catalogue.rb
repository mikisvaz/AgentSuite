# Dummy target catalogue: two tiny scenarios, generic rule overrides.
# Catalogue contract (CatalogueBox): builder methods + a `definitions` list.
def d01
  define('D01', 'dummy', 'dummy scenario one',
         { 'list.txt' => "one\n" }, '', { 'list.txt' => "one\n" },
         { 'expected/list.txt' => "one\n" })
end

def d02
  define('D02', 'dummy', 'dummy scenario two',
         { 'list.txt' => "two\n" }, '', { 'list.txt' => "two\n" },
         { 'expected/list.txt' => "two\n" })
end

def definitions
  [d01, d02]
end
