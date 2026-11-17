# Synthetic consumer scaffold for the dossier-store test suite.
#
# A temporary PROJECT DIRECTORY per test case (never inside the
# Research installation, never real user data): the store root is the
# fixed <project>/research resolved from Dir.pwd at execution time, so
# tests scaffold a project, Dir.chdir into it, and dispatch tasks.
# Provides:
#
#   - scaffold_project: a fresh temp project whose research/ root is
#     laid out with a complete synthetic consumer tree (markdown docs,
#     TSV, JSON, a binary file with a recorded SHA-256, a
#     reference-mode source file destined for later mutation in drift
#     tests);
#   - in_project: run a block with Dir.chdir'd into a scaffolded
#     project, restoring the original cwd afterwards;
#   - digest_of / assert_bytes: byte-preservation assertions based on
#     SHA-256 digests, never on normalized strings.
#
# This file is a test helper, not a Test::Unit case: no class here
# subclasses Test::Unit::TestCase, so per-file discovery finds no
# tests in it directly (it is require'd by the case files).

require 'fileutils'
require 'tmpdir'
require 'digest'
require 'scout'
require 'json'

module DossierFixtures
  BINARY_BYTES = (0..255).map(&:chr).join * 4 # 1024 known bytes

  class << self
    # A unique temp base directory for one test case; caller is
    # responsible for cleanup (DossierFixtures.cleanup on teardown).
    def tmp_base(label)
      # Scout.tmp, NOT Dir.tmpdir: reference-mode fixtures must sit in a
      # durable location, or the C2/R10 ephemerality classifier correctly
      # rejects them (EPHEMERAL_ROOTS covers /tmp and friends).
      dir = File.join(Scout.tmp.dossier_tests.find.to_s,
                      "#{label}-#{Process.pid}-#{rand(1_000_000_000)}")
      FileUtils.mkdir_p(dir)
      dir
    end

    def cleanup(dir)
      FileUtils.remove_entry(dir) if dir && File.exist?(dir)
    end

    # Materialize a synthetic temp PROJECT (the working-project context
    # the tasks resolve <project>/research from) with its research/
    # store root laid out and a synthetic source tree of known bytes.
    # Returns the project path; the store root is <project>/research.
    def scaffold_project(label)
      base = tmp_base(label)
      project = File.join(base, 'project')
      root = File.join(project, 'research')
      $dossier_fixture_registry << [base, project]
      FileUtils.mkdir_p(project)
      Research::Layout.ensure_root!(root)

      write_sources(File.join(base, 'sources'))
      project
    end

    # Run a block with the given project as the working directory
    # Store-level unit tests (no task dispatch): return the research
    # root of a scaffolded project. Sources live beside the project
    # under <base>/sources; callers derive them with
    # File.join(File.dirname(root), 'sources').
    def scaffold_root(label)
      project = scaffold_project(label)
      File.join(project, 'research')
    end

    # (task bodies resolve <cwd>/research), restoring the original cwd.
    def in_project(project)
      # The suite's cwd may be a project directory deleted by an
      # earlier teardown; capture a stable origin ONCE per process
      # (the suite launch dir) and chdir through it. Dir.open by fd
      # may be unavailable, so keep it simple: rescue and use tmpdir.
      origin = ($dossier_stable_origin ||= begin
        File.directory?(Dir.pwd) ? Dir.pwd : Dir.tmpdir
      end)
      Dir.chdir(project)
      begin
        yield project
      ensure
        Dir.chdir(origin)
      end
    end

    # The synthetic source tree (never inside the research root):
    # returns the sources dir path.
    def write_sources(dir)
      FileUtils.mkdir_p(dir)

      write(File.join(dir, 'note.md'), <<~MD)
        # Working note

        Synthetic consumer document for dossier store tests.
        Second content line.
      MD

      write(File.join(dir, 'table.tsv'), <<~TSV)
        #\tkey\tvalue
        row1\talpha\t1
        row2\tbeta\t2
      TSV

      write(File.join(dir, 'meta.json'), JSON.pretty_generate(
        'kind' => 'synthetic', 'rows' => 2, 'tags' => %w[fixture dossier]
      ) + "\n")

      write(File.join(dir, 'binary.bin'), BINARY_BYTES)

      # Reference-mode source intended to be mutated later (drift tests
      # copy it into a dossier, then mutate the copy outside a
      # transaction).
      write(File.join(dir, 'reference.md'), <<~MD)
        # Reference

        Body line that will drift.
      MD

      dir
    end

    def write(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, content)
      path
    end

    def digest_of(path)
      Digest::SHA256.file(path).hexdigest
    end

    def digest_bytes(bytes)
      Digest::SHA256.hexdigest(bytes)
    end

    # Record digests of every file under a tree (relative names -> hex).
    def tree_digests(dir)
      result = {}
      Dir.glob(File.join(dir, '**', '*')).sort.each do |p|
        next unless File.file?(p)

        rel = p.delete_prefix(dir + File::SEPARATOR)
        result[rel] = digest_of(p)
      end
      result
    end
  end
end

$dossier_fixture_registry = []

require_relative '../../lib/Research/layout'

# Test::Unit auto-runs whatever subclasses Test::Unit::TestCase at load;
# give every dossier test case shared teardown of the fixture registry.
module DossierFixtureTeardown
  def teardown
    super
    # Leave any (soon-deleted) project cwd before removing fixtures,
    # or later Dir.pwd calls in this process fail with getcwd ENOENT.
    origin = ($dossier_stable_origin ||= Dir.tmpdir)
    Dir.chdir(origin) rescue nil
    $dossier_fixture_registry.each { |base, _project| DossierFixtures.cleanup(base) }
    $dossier_fixture_registry.clear
  end
end
