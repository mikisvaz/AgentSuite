# Revision store and mutation transactions for the dossier store.
#
# THE COHERENCE RULE. A dossier revision is a coherent unit of
#   (a) the exact bytes of every authored document, and
#   (b) the exact versions (digest) of every attachment.
# Durable state is CONTENT-ADDRESSED: every committed byte lives once in
# store/objects/<sha256> and is never modified or deleted afterwards. A
# revision record store/history/rN.json pins, for each document name and
# each attachment slot/name, the digest of the object that revision
# displays. README.md, supplements/* and evidence/* are VIEWS materialized
# from objects; the current pointer <root>/meta/<ID>.current names the
# revision whose record defines the views. Because every object a record
# references was durably written before the record existed, any revision
# can be re-materialized at any time (Store#restore_views!).
#
# THE COMMIT PROTOCOL (and its interruption semantics — the paragraph
# WO-2 requires; feeds doc/developer later).
#
#   Phase S (stage):   every new byte goes to store/objects/<digest>
#                      (write_atomic: same-dir tmp, fsync, rename).
#                      Content addressing makes this idempotent and
#                      invisible: nothing references the object yet.
#   Phase J (journal): the complete revision record rN+1.json is written
#                      atomically into store/history/ — still
#                      unreferenced by the pointer.
#   Phase M (marker):  store/inflight is atomically written, containing
#                      rN+1. THE MARKER IS THE DISAMBIGUATOR: it says
#                      "view materialization for rN+1 has begun".
#   Phase V (views):   README.md, supplements/*, evidence/* are
#                      re-materialized from rN+1's objects.
#   Phase C (commit):  the pointer is atomically set to rN+1 and the
#                      marker is removed.
#
# An interrupted commit leaves: pointer at the old revision, marker
# naming rN+1, and rN+1's objects + journal fully on disk (S and J
# precede M). Individually atomic file writes are NOT an atomic dossier
# commit — that is why the marker exists. DETECTION: the next Store
# operation (and every transaction, before doing anything else) runs
# recovery under the per-dossier lock: a marker whose revision has a
# journal record means an interrupted commit, and recovery REDOES it
# deterministically — materialize views from rN+1's objects, set the
# pointer to rN+1, remove the marker — after which the dossier is exactly
# as if the commit had completed (the redo is safe because all redo
# inputs are immutable and were durable before the marker). A marker
# whose journal record is missing is loud corruption (Corrupt). With no
# marker, views that do not hash to the current record's digests are
# EXTERNAL DRIFT (someone edited README.md outside a transaction): the
# mutation is REJECTED (Drift, with observed and pinned digests);
# Store.restore_views! mechanically repairs views from the current
# record, and the caller may then re-attempt. There is no on-disk state
# from which the next operation cannot either recover or refuse loudly;
# orphans above the pointer (unreferenced journals/objects from crashes
# before M) are swept on open and never confuse a reader, because
# readers consult pointer -> record -> objects, not stray files.
#
# CONCURRENCY. Every mutation takes the per-dossier lock
# <root>/meta/<ID>.lock through Open.lock BEFORE reading state, so
# recovery, expected_revision verification, drift detection, staging and
# commit are one serialized critical section. Readers take no lock; a
# reader that wants an exactly-consistent snapshot reads the pointer,
# the record, and the objects (all immutable once written). Views are
# an eventually-consistent convenience for humans and non-transactional
# tools.
#
# OPTIMISTIC CONCURRENCY + DRIFT. A mutation states expected_revision
# (the caller's view). Under the lock, the current pointer must equal
# it; a mismatch raises StaleRevision. Authored-document and attachment
# views must hash to the current record's digests; a mismatch with no
# marker raises Drift (external edit), never silent overwrite.
#
# NO-OP SEMANTICS. If the staged revision would equal the current one
# (identical document digest map and attachment inventory), the
# transaction returns changed: false, revision: current and writes
# nothing (no objects beyond what dedup already placed, no journal, no
# marker, no pointer move). Detected after staging, before phase S —
# the cheapest correct layer.
#
# IMMUTABILITY. Objects and journal records are never rewritten after
# their write; views are the only bytes a commit rewrites, and only
# between the marker and the pointer swap.

require 'json'
require 'fileutils'
require 'scout'
require_relative 'store_bytes'
require_relative 'layout'

module Research
  module Store
    class Error < StandardError; end
    class Missing < Error; end
    class StaleRevision < Error; end
    class Drift < Error; end
    class Corrupt < Error; end
    class Interrupted < Error; end

    class << self
      # -------------------------------------------------------------
      # Reads (no lock)
      # -------------------------------------------------------------

      # current_revision(root, type, id) -> { 'revision' => Integer,
      # 'record' => Hash, 'dir' => dossier dir }
      def current_revision(root, type, id)
        dir = Layout.dossier_dir(root, type, id)
        pointer = Layout.current_pointer_path(root, type, id)
        raise Missing, "no current revision for #{id}" unless File.file?(pointer)

        number = read_pointer(pointer)
        { 'revision' => number,
          'record' => read_revision(dir, number),
          'dir' => dir }
      end

      def read_pointer(pointer)
        text = StoreBytes.read(pointer).strip
        unless text =~ /\A\d+\z/
          raise Corrupt, "current pointer at #{pointer} is not an integer: #{text.inspect}"
        end
        text.to_i
      end

      def read_revision(dir, number)
        path = Layout.revision_path(dir, number)
        unless File.file?(path)
          raise Missing, "revision record r#{number} not found for #{File.basename(dir)}"
        end
        begin
          JSON.parse(StoreBytes.read(path))
        rescue JSON::ParserError => e
          raise Corrupt, "revision record #{path} is not valid JSON: #{e.message}"
        end
      end

      # Byte content of a document/attachment view named by a record.
      def object_bytes(dir, record, name)
        digest = record_digest_for(record, name)
        path = Layout.object_path(dir, digest)
        raise Missing, "object #{digest} for #{name.inspect} missing in #{File.basename(dir)}" unless File.file?(path)

        StoreBytes.read(path)
      end

      # -------------------------------------------------------------
      # Recovery / repair (call under the dossier lock; transaction does)
      # -------------------------------------------------------------

      # recover!(root, type, id) -> nil, or {'recovered' => revision}
      # Redo an interrupted commit when the inflight marker is present;
      # sweep orphans above the pointer otherwise.
      def recover!(root, type, id)
        dir = Layout.dossier_dir(root, type, id)
        marker = marker_path(dir)
        pointer = Layout.current_pointer_path(root, type, id)
        return nil unless File.file?(marker)

        number = read_marker(marker)
        record_path = Layout.revision_path(dir, number)
        unless File.file?(record_path)
          raise Corrupt, "inflight marker names r#{number} but its journal " \
                         "record is missing (#{record_path}); refusing to guess"
        end
        record = read_revision(dir, number)
        materialize_views!(dir, record)
        StoreBytes.write_atomic(pointer, number.to_s)
        FileUtils.rm_f(marker)
        sweep_orphans!(dir)
        { 'recovered' => number }
      end

      # restore_views!(root, type, id) -> true
      # Mechanical drift repair: re-materialize every view from the
      # current revision's objects. Rejects when there is no current
      # revision.
      def restore_views!(root, type, id)
        current = current_revision(root, type, id)
        materialize_views!(current['dir'], current['record'])
        true
      end

      # -------------------------------------------------------------
      # Transaction
      # -------------------------------------------------------------

      # Store.transaction(root, type, id, expected_revision:,
      # allow_create:, on_stage:, fault:)
      #
      #   expected_revision: Integer the caller read; nil + allow_create
      #     creates the dossier at revision 1.
      #   on_stage: ->(ctx) staged via the yielded Ctx (write_document,
      #     delete_document, attach_evidence); a block given to
      #     Store.transaction becomes on_stage.
      #   fault: deterministic fault injection emulating process death at
      #     a protocol boundary: :after_stage, :after_journal,
      #     :after_marker (views not yet written), :mid_views (half the
      #     views written), :after_views (before pointer),
      #     :after_pointer (before marker removal). Raises Interrupted;
      #     the on-disk state equals a kill at that point, and the next
      #     transaction's recovery path is what the tests exercise.
      #
      # Returns {'id','revision','changed','documents','attachments',
      # 'record','record_digest'}.
      # allow_drift (default false) is the EXPLICIT, capture-only escape
      # hatch from verify_no_external_drift!. It exists so dossier_capture
      # can adopt externally edited documents inside a transaction while
      # remaining guarded by expected_revision and the observed digests it
      # records. Every other caller keeps the unconditional drift
      # rejection: ordinary mutations never adopt external edits.
      def transaction(root, type, id, expected_revision: nil,
                      allow_create: false, on_stage: nil, fault: nil,
                      allow_drift: false, &block)
        on_stage ||= block
        dir = Layout.dossier_dir(root, type, id)
        lock_path = dossier_lock_path(root, type, id)
        pointer = Layout.current_pointer_path(root, type, id)

        Open.lock(lock_path) do
          recover!(root, type, id)
          sweep_orphan_journals!(dir)

          existing = File.file?(pointer)
          current = existing ? read_pointer(pointer) : nil
          current_record = current ? read_revision(dir, current) : nil

          verify_expected_revision!(existing, current, expected_revision,
                                    allow_create, id)
          verify_no_external_drift!(dir, current_record) if current && !allow_drift

          # Tree exists only after a dossier's first successful
          # verification: a rejected transaction leaves no directories.
          Layout.ensure_dossier_tree!(dir)

          ctx = Ctx.new(self, root, type, id, dir, current, current_record)
          on_stage.call(ctx) if on_stage

          fault!(:after_stage, fault)
          if ctx.no_op?(current_record)
            next no_op_result(ctx)
          end

          validate_staged!(ctx)
          new_revision = current ? current + 1 : 1

          # Phase S: objects for every staged byte (idempotent, ordered).
          stage_objects!(dir, ctx)

          # Phase J: journal the complete record.
          record = build_revision_record(ctx, new_revision)
          write_journal(dir, new_revision, record)
          fault!(:after_journal, fault)

          # Phase M: the marker that disambiguates redo from drift.
          marker = marker_path(dir)
          StoreBytes.write_atomic(marker, new_revision.to_s)
          fault!(:after_marker, fault)

          # Phase V: materialize views (marker present => redo-able).
          materialize_views!(dir, record, fault: fault)
          fault!(:after_views, fault)

          # Phase C: pointer swap — the linearization point.
          StoreBytes.write_atomic(pointer, new_revision.to_s)
          fault!(:after_pointer, fault)
          FileUtils.rm_f(marker)

          sweep_orphans!(dir)

          { 'id' => id, 'revision' => new_revision, 'changed' => true,
            'documents' => record['documents'],
            'attachments' => record['attachments'],
            'record' => Layout.revision_path(dir, new_revision),
            'record_digest' => StoreBytes.digest(
              Layout.revision_path(dir, new_revision)
            ) }
        end
      end

      def dossier_lock_path(root, type, id)
        File.join(root.to_s, Layout::ROOT_META, "#{id}.lock")
      end

      # -------------------------------------------------------------
      # Internal
      # -------------------------------------------------------------

      # Deterministic pointer bytes for a reference-mode attachment
      # entry. The evidence view for a reference is a small text pointer
      # naming the absolute source and the observed digest — readable by
      # any tool, repairable from the record, and honest about NOT being
      # the source bytes. NEVER a symlink: a symlink would falsely claim
      # portability and would silently expose changed bytes.
      def reference_pointer_bytes(entry)
        lines = [
          'mode: reference',
          "source: #{entry['source']}",
          "digest: #{entry['digest']}",
          "size: #{entry['size']}",
          "slot: #{entry['slot']}",
          "name: #{entry['name']}",
          "attached_at: #{entry['attached_at']}"
        ]
        caption = entry['caption']
        lines << "caption: #{caption}" if caption && !caption.to_s.empty?
        lines << 'NOTE: the source is external; this file is a pointer, ' \
                 'not the evidence bytes'
        (lines.join("\n") + "\n")
      end

      def reference_pointer_digest(entry)
        StoreBytes.digest_bytes(reference_pointer_bytes(entry))
      end

      def marker_path(dir)
        File.join(Layout.store_dir(dir), 'inflight')
      end

      def read_marker(marker)
        text = StoreBytes.read(marker).strip
        unless text =~ /\A\d+\z/
          raise Corrupt, "inflight marker at #{marker} is not an integer: #{text.inspect}"
        end
        text.to_i
      end

      def record_digest_for(record, name)
        docs = record['documents'] || {}
        atts = record['attachments'] || {}
        entry = docs[name] || atts[name]
        entry = entry['digest'] if entry.is_a?(Hash)
        raise Missing, "revision record names no object for #{name.inspect}" unless entry

        entry
      end

      # Write exactly the views the record defines, from objects; drop
      # view files the record no longer lists. fault: :mid_views
      # materializes only the first view then raises Interrupted.
      def materialize_views!(dir, record, fault: nil)
        docs = record['documents'] || {}
        atts = record['attachments'] || {}
        written = 0
        views = []
        docs.keys.sort.each { |n| views << [n, File.join(dir, n)] }
        views.map! { |n, p| n == Layout::DOC ? [n, Layout.doc_path(dir)] : [n, p] }
        atts.keys.sort.each { |n| views << [n, File.join(Layout.evidence_dir(dir), n)] }
        views.sort_by(&:last).each do |name, target|
          if fault == :mid_views && written.positive?
            raise Interrupted, 'fault injection at mid_views'
          end
          # Nested supplement documents need their parent directories.
          dirnames = [File.dirname(target)]
          dirnames << File.dirname(Layout.doc_path(dir)) if name == Layout::DOC
          dirnames.uniq.each { |d| FileUtils.mkdir_p(d) }
          # Reference-mode attachments materialize their POINTER object
          # (deterministic in the entry), never the external source
          # bytes and never a symlink.
          body =
            if (entry = atts[name]).is_a?(Hash) && entry['mode'] == 'reference'
              pd = entry['pointer_digest']
              pbytes = Store.reference_pointer_bytes(entry)
              raise Corrupt, "pointer digest mismatch for reference #{name}" unless StoreBytes.digest_bytes(pbytes) == pd

              pbytes
            else
              object_bytes(dir, record, name)
            end
          StoreBytes.write_atomic(target, body)
          written += 1
        end
        raise Interrupted, 'fault injection at mid_views' if fault == :mid_views && written.zero?

        # Drop stale view files (removed in this revision).
        FileUtils.rm_f(Layout.doc_path(dir)) if !docs.key?(Layout::DOC) && File.file?(Layout.doc_path(dir))
        prune_view_dir(Layout.supplement_dir(dir),
                       docs.keys.select { |k| k.start_with?("#{Layout::SUPPLEMENTS}/") }
                            .map { |k| k.split('/', 2)[1] })
        return unless File.directory?(Layout.evidence_dir(dir))

        keep_by_parent = {}
        atts.keys.each do |k|
          slot, name = k.split('/', 2)
          keep_by_parent[slot] ||= []
          keep_by_parent[slot] << name
        end
        Dir.children(Layout.evidence_dir(dir)).sort.each do |slot|
          prune_view_dir(File.join(Layout.evidence_dir(dir), slot),
                         keep_by_parent[slot])
        end
      end

      # Prune view files/directories not in +keep+ (recursive: nested
      # supplement subdirectories that no staged document names are
      # removed wholesale). +keep+ entries may themselves be nested
      # relative paths ('sub/inner.md').
      def prune_view_dir(dir, keep)
        return unless File.directory?(dir)

        keep ||= []
        keep_files = []
        keep_dirs = []
        keep.each do |rel|
          parts = rel.to_s.split('/')
          keep_dirs << File.join(dir, *parts[0...-1]) if parts.length > 1
          keep_files << File.join(dir, rel.to_s)
        end
        Dir.glob(File.join(dir, '**', '*')).sort.reverse.each do |p|
          next if keep_files.include?(p)
          if File.directory?(p)
            FileUtils.rm_rf(p) unless keep_dirs.include?(p)
          else
            FileUtils.rm_f(p)
          end
        end
      end

      def view_path(dir, name)
        if name == Layout::DOC
          Layout.doc_path(dir)
        else
          File.join(dir, name)
        end
      end

      def validate_staged!(ctx)
        docs = ctx.staged_documents
        unless docs.key?(Layout::DOC)
          raise Error, "a dossier must keep its authored document #{Layout::DOC.inspect}"
        end
        true
      end

      def stage_objects!(dir, ctx)
        ctx.staged_document_bytes.each do |name, bytes|
          digest = StoreBytes.digest_bytes(bytes)
          target = Layout.object_path(dir, digest)
          StoreBytes.write_atomic(target, bytes) unless File.file?(target)
        end
        ctx.staged_attachment_bytes.each_value do |info|
          target = Layout.object_path(dir, info['digest'])
          StoreBytes.write_atomic(target, info['bytes']) unless File.file?(target)
        end
        # Reference-mode attachments stage their pointer object once; the
        # pointer bytes are deterministic in the entry contents.
        ctx.staged_attachments.each_value do |entry|
          next unless entry.is_a?(Hash) && entry['mode'] == 'reference'

          pd = entry['pointer_digest']
          target = Layout.object_path(dir, pd)
          StoreBytes.write_atomic(target, Store.reference_pointer_bytes(entry)) unless File.file?(target)
        end
        true
      end

      def build_revision_record(ctx, new_revision)
        { 'id' => ctx.id,
          'type' => ctx.type,
          'revision' => new_revision,
          'timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
          'change_note' => ctx.change_note,
          'documents' => ctx.staged_documents,
          'attachments' => ctx.staged_attachments }
      end

      def write_journal(dir, new_revision, record)
        path = Layout.revision_path(dir, new_revision)
        fresh = JSON.pretty_generate(record) + "\n"
        if File.file?(path) && StoreBytes.read(path) != fresh
          raise Corrupt, "revision record #{path} already exists with " \
                         'different content; refusing to overwrite'
        end
        StoreBytes.write_atomic(path, fresh)
      end

      def fault!(point, fault)
        return unless fault == point

        raise Interrupted, "fault injection at #{point}"
      end

      # Journals above the current pointer can only be crash leftovers:
      # a dossier lock is held for the whole transaction, so no live
      # writer can be mid-commit. Remove them before staging so a fresh
      # commit at that revision is never blocked by garbage.
      def sweep_orphan_journals!(dir)
        return unless File.directory?(Layout.history_dir(dir))

        cur = compute_pointer(dir)
        Dir.children(Layout.history_dir(dir)).each do |n|
          m = %r{\Ar(\d+)\.json\z}.match(n)
          next unless m && Integer(m[1]) > cur

          FileUtils.rm_f(File.join(Layout.history_dir(dir), n))
        end
        true
      end

      def verify_expected_revision!(existing, current, expected, allow_create, id)
        if existing
          unless Integer === expected && expected == current
            raise StaleRevision,
                  "stale mutation of #{id}: current revision is #{current}; " \
                  "caller expected #{expected.inspect}; re-read the dossier " \
                  'and re-apply the mutation'
          end
        else
          unless allow_create
            raise Missing, "dossier #{id} has no current revision; pass " \
                           'allow_create: true to create it (revision 1)'
          end
          if expected && expected != 0
            raise StaleRevision,
                  "dossier #{id} does not exist (revision 1 not committed) " \
                  "but caller expected #{expected.inspect}"
          end
        end
      end

      # With no inflight marker, views must hash to the current record.
      def verify_no_external_drift!(dir, current_record)
        marker = marker_path(dir)
        if File.file?(marker)
          raise Corrupt, "inflight marker present outside a transaction " \
                         "(#{marker}); recover! must run first"
        end

        expected_docs = current_record['documents'] || {}
        expected_atts = current_record['attachments'] || {}

        actual_docs = view_digests(Layout.doc_path(dir),
                                   Layout.supplement_dir(dir),
                                   Layout::DOC, Layout::SUPPLEMENTS)
        expected_docs.each do |name, digest|
          actual = actual_docs[name]
          next if actual == digest

          raise Drift, drift_message(dir, name, digest, actual)
        end
        extra = actual_docs.keys - expected_docs.keys
        unless extra.empty?
          raise Drift, "external drift on #{File.basename(dir)}: authored " \
                       "document #{extra.first.inspect} exists on disk but " \
                       'the current revision does not list it; stage it in a ' \
                       'transaction or remove it (run dossier_check to see ' \
                       'the full drift report)'
        end

        expected_atts.each do |name, info|
          digest = info.is_a?(Hash) ? (info['mode'] == 'reference' ? info['pointer_digest'] : info['digest']) : info
          path = File.join(Layout.evidence_dir(dir), name)
          actual = File.file?(path) ? StoreBytes.digest(path) : nil
          next if actual == digest

          raise Drift, drift_message(dir, name, digest, actual)
        end
        # Evidence files the record does not list are drift too.
        if File.directory?(Layout.evidence_dir(dir))
          expected_names = expected_atts.keys
          Dir.glob(File.join(Layout.evidence_dir(dir), '**', '*')).sort
             .select { |p| File.file?(p) }
             .each do |p|
            rel = p.delete_prefix("#{Layout.evidence_dir(dir)}/")
            next if expected_names.include?(rel)

            raise Drift, "external drift on #{File.basename(dir)}: evidence " \
                         "file #{rel.inspect} exists on disk but the current " \
                         'revision does not list it; stage it in a ' \
                         'transaction or remove it (run dossier_check to ' \
                         'see the full drift report)'
          end
        end
        true
      end

      def drift_message(dir, name, pinned, actual)
        "external drift on #{File.basename(dir)}: #{name.inspect} hashes to " \
        "#{actual || 'MISSING'} but the current revision pinned #{pinned}; " \
        'the file was modified outside a transaction. Restore the pinned ' \
        'bytes or run dossier_check for the full mechanical integrity ' \
        'report, then re-apply the change as a new revision'
      end

      def view_digests(doc_path, supplement_dir, doc_name, supplements)
        result = {}
        result[doc_name] = StoreBytes.digest(doc_path) if File.file?(doc_path)
        if File.directory?(supplement_dir)
          Dir.glob(File.join(supplement_dir, '**', '*')).sort.each do |p|
            next unless File.file?(p)

            rel = p.delete_prefix(supplement_dir + File::SEPARATOR)
            result["#{supplements}/#{rel}"] = StoreBytes.digest(p)
          end
        end
        result
      end

      def no_op_result(ctx)
        { 'id' => ctx.id, 'revision' => ctx.current, 'changed' => false,
          'documents' => ctx.staged_documents,
          'attachments' => ctx.staged_attachments,
          'record' => ctx.current_record_path,
          'record_digest' => ctx.current_record_digest }
      end

      # Sweep journals above the pointer and stale tmp files. OBJECTS ARE
      # NEVER SWEPT: lower revisions and interrupted-redo inputs reference
      # them, and content addressing makes them self-deduplicating.
      def sweep_orphans!(dir)
        history = Layout.history_dir(dir)
        if File.directory?(history)
          keep = compute_pointer(dir)
          Dir.children(history).map do |n|
            m = n.match(/\Ar(\d+)\.json\z/)
            m && m[1].to_i
          end.compact.sort.each do |number|
            next if number <= keep

            FileUtils.rm_f(Layout.revision_path(dir, number))
          end
        end
        Dir.glob(File.join(dir, '**', "#{StoreBytes::TMP_PREFIX}*")).each do |tmp|
          FileUtils.rm_f(tmp)
        end
        true
      end

      def compute_pointer(dir)
        pointer = pointer_for_dossier(dir)
        File.file?(pointer) ? read_pointer(pointer) : 0
      end

      def pointer_for_dossier(dir)
        id = File.basename(dir)
        # dir = <root>/<type-plural>/<ID>: two dirnames reach the root.
        root = File.dirname(File.dirname(dir))
        File.join(root, Layout::ROOT_META, "#{id}.current")
      end
    end

    # Transaction context: the ONLY sanctioned staging surface. Staging
    # builds digest maps in memory; durable writes happen at commit
    # (phase S) through Store#stage_objects!.
    class Ctx
      attr_reader :root, :type, :id, :dir, :current, :current_record
      attr_accessor :change_note

      def initialize(store, root, type, id, dir, current, current_record)
        @store = store
        @root = root
        @type = type
        @id = id
        @dir = dir
        @current = current
        @current_record = current_record
        @documents = current_record ? (current_record['documents'] || {}).dup : {}
        @attachments = current_record ? (current_record['attachments'] || {}).dup : {}
        @document_bytes = {}
        @attachment_bytes = {}
      end

      # --- document staging -----------------------------------------

      # write_document('README.md' | 'supplements/x.md', bytes) -> digest
      # Task-layer document names pass through unchanged (single-segment
      # supplement leaves already satisfy the store slot rules).
      def write_document(name, bytes)
        check_encoding!(bytes)
        check_document_name!(name)
        digest = StoreBytes.digest_bytes(bytes)
        @documents[name] = digest
        @document_bytes[name] = bytes
        digest
      end

      def delete_document(name)
        check_document_name!(name)
        return false unless @documents.key?(name)

        @documents.delete(name)
        @document_bytes.delete(name)
        true
      end

      # --- attachment staging ---------------------------------------

      # attach_evidence(slot, name, content, meta: nil) -> info Hash
      # Copy-mode staging: bytes immutable once staged; identical bytes at
      # the same slot/name is a dedup; different bytes is a hard error
      # (the task layer owns the explicit-replace remedy). Optional meta
      # (mode/source/caption/declared/attached_at from the task layer)
      # is merged into the revision-record entry verbatim.
      def attach_evidence(slot, name, content, meta: nil)
        check_slot_name!(slot)
        check_attachment_name!(name)
        key = "#{slot}/#{name}"
        bytes = String === content ? content : File.binread(content.to_s)
        digest = StoreBytes.digest_bytes(bytes)
        if (existing = @attachments[key])
          existing_digest = existing.is_a?(Hash) ? existing['digest'] : existing
          if existing_digest == digest
            return { 'slot' => slot.to_s, 'name' => name.to_s,
                     'digest' => digest, 'dedup' => true }
          end

          raise Store::Error,
                "attachment #{key} already staged with different bytes; " \
                'attachments are immutable once attached — attach under a ' \
                'new name or replace it explicitly'
        end
        entry = { 'digest' => digest, 'size' => bytes.bytesize,
                  'mode' => 'copy' }
        entry.merge!(meta) if meta
        @attachments[key] = entry
        @attachment_bytes[key] = { 'bytes' => bytes, 'digest' => digest }
        { 'slot' => slot.to_s, 'name' => name.to_s, 'digest' => digest,
          'dedup' => false }
      end

      # attach_reference(slot, name, meta) -> info Hash
      # Reference-mode staging: NO bytes are retained; the entry carries
      # the authorized source identity and the OBSERVED digest. The
      # materialized evidence view for a reference is a deterministic
      # POINTER file (see Store.reference_pointer_bytes), never a
      # symlink and never the source bytes. meta must carry 'digest'
      # and 'size' (observed at attach time).
      def attach_reference(slot, name, meta)
        check_slot_name!(slot)
        check_attachment_name!(name)
        key = "#{slot}/#{name}"
        if (existing = @attachments[key])
          existing_digest = existing.is_a?(Hash) ? existing['digest'] : existing
          if existing_digest == meta['digest']
            return { 'slot' => slot.to_s, 'name' => name.to_s,
                     'digest' => meta['digest'], 'dedup' => true }
          end

          raise Store::Error,
                "attachment #{key} already staged with different bytes; " \
                'attachments are immutable once attached — attach under a ' \
                'new name or replace it explicitly'
        end
        entry = { 'mode' => 'reference' }.merge(meta)
        entry['pointer_digest'] = Store.reference_pointer_digest(entry)
        @attachments[key] = entry
        { 'slot' => slot.to_s, 'name' => name.to_s,
          'digest' => meta['digest'], 'dedup' => false }
      end

      # Remove a staged/committed attachment entry (explicit replacement).
      # Objects are never deleted: history keeps referencing them.
      def drop_attachment!(slot, name)
        key = "#{slot}/#{name}"
        @attachments.delete(key)
        @attachment_bytes.delete(key)
        true
      end

      # --- staged state ---------------------------------------------

      def staged_documents
        @documents
      end

      def staged_attachments
        @attachments
      end

      def staged_document_bytes
        @document_bytes
      end

      def staged_attachment_bytes
        @attachment_bytes
      end

      def current_record_path
        @current ? Layout.revision_path(@dir, @current) : nil
      end

      def current_record_digest
        return nil unless @current

        StoreBytes.digest(current_record_path)
      end

      def no_op?(prior_record)
        return false if prior_record.nil?

        prior_record['documents'] == staged_documents &&
          prior_record['attachments'] == staged_attachments
      end

      private

      def check_document_name!(name)
        return if name == Layout::DOC
        return if name.start_with?("#{Layout::SUPPLEMENTS}/") &&
                  !name.split('/').any? { |seg| seg.empty? }

        raise Store::Error,
              "document name #{name.inspect} must be '#{Layout::DOC}' or " \
              "under '#{Layout::SUPPLEMENTS}/<...>'"
      end

      def check_slot_name!(slot)
        s = slot.to_s
        return if s =~ /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/ && !%w[. ..].include?(s)

        raise Store::Error, "invalid evidence slot #{slot.inspect}"
      end

      def check_attachment_name!(name)
        n = name.to_s
        return if n =~ /\A[A-Za-z0-9][A-Za-z0-9._ -]*\z/ && !%w[. ..].include?(n)

        raise Store::Error, "invalid attachment name #{name.inspect}"
      end

      def check_encoding!(bytes)
        return if bytes.encoding == Encoding::UTF_8 && bytes.valid_encoding?

        raise Store::Error,
              "document bytes must be valid UTF-8 (got " \
              "#{bytes.encoding}#{bytes.valid_encoding? ? '' : ', invalid'})"
      end
    end
  end
end
