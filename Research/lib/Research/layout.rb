# Dossier directory layout for the native Research store.
#
# One dossier per scientific record, addressed by root-local ID with a
# two-letter type prefix: Q-001 (question), C-001 (claim), H-001
# (hypothesis). Directory layout inside <root>:
#
#   <root>/questions/Q-001/          dossier home
#   <root>/claims/C-001/
#   <root>/hypotheses/H-001/
#   <root>/meta/                     root-level machine area (id counters,
#                                     per-dossier locks, <id>.current
#                                     revision pointers)
#
# Inside a dossier:
#
#   README.md                authored document (VIEW, machine-materialized)
#   supplements/<name>       supplementary authored documents (VIEWS)
#   evidence/<slot>/<name>   evidence attachments (VIEWS; bytes immutable
#                            once attached)
#   store/objects/<sha256>   content-addressed object store — the ONLY
#                            durable copy of every version of every
#                            authored document and attachment ever
#                            committed (never modified, never deleted)
#   store/history/rN.json    immutable revision records (see Store)
#
# VIEWS vs OBJECTS. README.md, supplements/* and evidence/* are
# machine-materialized views of the current revision's objects; they exist
# for human and tool readability. The revision record + objects are the
# source of truth. Views are re-derivable at any time from the current
# record (Store.restore_views!), which is what makes both crash recovery
# and drift repair possible.
#
# Area separation (the hard rule this module encodes): editing authored
# documents happens only inside Store transactions, and a transaction
# routes every change kind to exactly one area — new bytes go to
# store/objects/<digest>, records to store/history/, views are
# re-materialized from objects. Attachment bytes and history are never
# rewritten by a document edit. The layout module itself provides pure
# path algebra plus ensure-tree creation; it performs no I/O beyond mkdir.

require 'fileutils'

module Research
  module Layout
    class Error < StandardError; end

    TYPE_DIRS = { 'question' => 'questions', 'claim' => 'claims',
                  'hypothesis' => 'hypotheses' }.freeze
    TYPES = TYPE_DIRS.keys.freeze
    DOC = 'README.md'.freeze
    SUPPLEMENTS = 'supplements'.freeze
    EVIDENCE = 'evidence'.freeze
    STORE = 'store'.freeze
    OBJECTS = 'objects'.freeze
    HISTORY = 'history'.freeze
    ROOT_META = 'meta'.freeze

    class << self
      def valid_type?(type)
        TYPE_DIRS.key?(type)
      end

      def type_dir(root, type)
        raise Error, "unknown dossier type #{type.inspect}" unless valid_type?(type)
        File.join(root.to_s, TYPE_DIRS.fetch(type))
      end

      # dossier_dir(root, type, id) — id like 'Q-001'; the type embedded in
      # the id prefix MUST agree with the type argument (an ID in the wrong
      # directory is a hard error, not a refile).
      def dossier_dir(root, type, id)
        raise Error, "id #{id.inspect} does not match type #{type.inspect}" unless id_matches_type?(id, type)
        File.join(type_dir(root, type), id)
      end

      def id_matches_type?(id, type)
        id.to_s.start_with?("#{Research::Ids::TYPES.fetch(type)}-")
      end

      def doc_path(dir)
        File.join(dir, DOC)
      end

      def supplement_dir(dir)
        File.join(dir, SUPPLEMENTS)
      end

      def evidence_dir(dir)
        File.join(dir, EVIDENCE)
      end

      def store_dir(dir)
        File.join(dir, STORE)
      end

      def objects_dir(dir)
        File.join(dir, STORE, OBJECTS)
      end

      def object_path(dir, digest)
        File.join(objects_dir(dir), digest)
      end

      def history_dir(dir)
        File.join(dir, STORE, HISTORY)
      end

      def revision_path(dir, revision)
        File.join(history_dir(dir), "r#{revision}.json")
      end

      def current_pointer_path(root, type, id)
        File.join(root.to_s, ROOT_META, "#{id}.current")
      end

      def ids_dir(root)
        File.join(root.to_s, ROOT_META, 'ids')
      end

      # Create the full tree for a fresh dossier dir; caller has already
      # allocated the ID (Ids.allocate) and holds no other requirement.
      def ensure_dossier_tree!(dir)
        ensure_type_trees!(File.dirname(File.dirname(dir)))
        FileUtils.mkdir_p([supplement_dir(dir), evidence_dir(dir),
                           history_dir(dir), objects_dir(dir)])
      end

      # Root-level machine area + per-type dirs.
      def ensure_root!(root)
        FileUtils.mkdir_p(ids_dir(root.to_s))
        TYPES.each { |t| FileUtils.mkdir_p(type_dir(root.to_s, t)) }
      end

      def ensure_type_trees!(root)
        TYPES.each { |t| FileUtils.mkdir_p(type_dir(root.to_s, t)) }
      end

      # Enumerate dossier IDs of one type present on disk (sorted).
      def list_ids(root, type)
        dir = type_dir(root.to_s, type)
        return [] unless File.directory?(dir)
        Dir.children(dir).select { |e| File.directory?(File.join(dir, e)) }.sort
      end
    end
  end
end

require_relative 'ids'
