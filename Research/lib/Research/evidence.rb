# Shared evidence-model helpers for the evidence tasks (WO-4).
#
# Owns, independent of any Path kind:
#
#   - sandbox-authorized SOURCE resolution for reading and DESTINATION
#     authorization for writing, through the actual access policy
#     (LLM::Sandbox.authorize_path — the same layer the agent tool
#     surface uses; resolve_path component-realpaths existing symlinks
#     so symlink escapes and symlinked-parent writes are detected by
#     the OS-facing policy, not by string-prefix checks). A
#     model-supplied source path is NEVER a permission grant: grants
#     come from the process's configured sandbox grants only.
#   - the three-state citation validation ported from
#     research/return-path-citation-contract.md (C1-C5, R6-R14):
#     broken reference (hard error), ephemeral address (promote-or-
#     reject), durable-without-digest (warning). Mapping table below.
#   - source-change-during-acquisition detection for copy mode
#     (stat-read-recheck): the digest is computed from the RETAINED
#     bytes; a source that changed during the read is detected and
#     failed, never recorded as a digest of bytes we did not retain.
#   - declared-vs-verified production metadata separation (agent
#     declarations are recorded under 'declared_', never under any
#     'verified' key; nothing here proves a declared script produced
#     the accompanying bytes).
#
# No scientific semantics live here: attachments carry no validity,
# support/contradict status or strength. Captions are prose.

require 'scout-ai'
require 'json'
require 'fileutils'
require_relative 'tasks/common'

module Research
  # Shared evidence-model helpers for the evidence tasks. Lives outside
  # tasks/ because it declares no tasks (that directory now holds task
  # definition files only).
  module Evidence
      MODES = %w[copy reference].freeze
      ITEM_TEXT_FIELDS = %w[caption note].freeze

      # Durability classification per R10: temp roots that classify a
      # resolvable-now source as ephemeral.
      EPHEMERAL_ROOTS = %w[/tmp /var/tmp /dev/shm].freeze

      class << self
        # -------------------------------------------------------------
        # Sandbox-authorized source/destination resolution
        # -------------------------------------------------------------

        # authorize_read!(path) -> canonical absolute path
        # A model-supplied path is not a grant: only the process's own
        # configured sandbox grants (writable + read grants, plus the
        # research root) authorize reading here.
        def authorize_read!(path)
          authorize!(path, :read, 'evidence source')
        end

        def authorize_write!(path)
          authorize!(path, :write, 'evidence destination')
        end

        def authorize!(path, mode, label)
          decision = LLM::Sandbox.authorize_path(
            path,
            root: Dir.pwd,
            writable_paths: LLM::Sandbox.writable_grants(scope: 'Research'),
            read_paths: LLM::Sandbox.readable_grants(scope: 'Research'),
            mode: mode
          )
          unless decision.allowed
            raise ParameterException,
                  "#{label} #{path.inspect} is outside the granted paths " \
                  "for #{mode} access (reason: #{decision.reason}); a " \
                  'model-supplied path is not a permission grant'
          end
          decision.canonical_path
        end

        # -------------------------------------------------------------
        # Source acquisition (copy mode)
        # -------------------------------------------------------------

        # acquire_copy!(source) -> { 'bytes' =>, 'digest' =>, 'observed_size' => }
        # stat-read-recheck: size and mtime must be identical before and
        # after the read. A source that changes during acquisition is a
        # hard failure (re-read would race too); we never record a digest
        # of bytes we did not retain. Only regular files are accepted —
        # directories are an explicit unsupported operation, FIFOs and
        # device files likewise.
        def acquire_copy!(source)
          raise ParameterException,
                "broken reference: evidence source #{source.inspect} does not " \
                'exist' unless File.exist?(source)

          stat_before = File.stat(source)
          unless stat_before.file?
            kind = File.directory?(source) ? 'a directory' : 'not a regular file'
            raise ParameterException,
                  "evidence source #{source.inspect} is #{kind}; directory " \
                  'imports are not supported — attach regular files one by ' \
                  'one, or stage the directory contents through Workspace ' \
                  'and attach the staged files'
          end

          bytes = File.binread(source)
          stat_after = File.stat(source)
          if stat_before.size != stat_after.size ||
             stat_before.mtime != stat_after.mtime
            raise ParameterException,
                  "evidence source #{source.inspect} changed during " \
                  'acquisition (size/mtime moved while reading); the bytes ' \
                  'were not retained and no digest was recorded — re-run ' \
                  'the attach after the source is stable'
          end
          retained = StoreBytes.digest_bytes(bytes)
          if retained && stat_after.size != bytes.bytesize
            raise ParameterException,
                  "evidence source #{source.inspect} produced #{bytes.bytesize} " \
                  "bytes but stat reports #{stat_after.size}; refusing to " \
                  'record a digest of partially retained bytes'
          end

          { 'bytes' => bytes, 'digest' => retained,
            'observed_size' => bytes.bytesize }
        end

        # -------------------------------------------------------------
        # Reference-mode citation validation (C1-C5, R6-R14 port)
        # -------------------------------------------------------------
        #
        # Mapping (contract rule -> code path here):
        #   C1/R7  resolvability  -> classify_reference! existence arm
        #   C2/R10 lifetime       -> classify_reference! ephemeral arm
        #   C3     inspection     -> pointer is a plain readable text file
        #                            (Store.reference_pointer_bytes)
        #   C4/R12 integrity      -> digest recorded at attach; mismatch at
        #                            read time -> 'changed', never substitute
        #   R10    promote-or-reject -> ephemeral arm message names copy mode
        #                            as the promote remedy
        #   R11    promote remedy -> copy mode IS the promotion: bytes land
        #                            in the dossier's content-addressed store
        #   R12    no-digest      -> warning recorded ('warnings' in result)

        # classify_reference!(source, canonical) -> classification Hash
        #   { 'class' => 'durable'|'ephemeral', 'job_tree' => bool }
        # Raises ParameterException (hard error) for broken references.
        def classify_reference!(source, canonical)
          unless canonical && File.file?(canonical)
            raise ParameterException,
                  "broken reference: #{source.inspect} does not resolve to " \
                  'an existing regular file (C1/R7: a result ref must name ' \
                  'one concrete artifact on persistent storage)'
          end
          raise ParameterException, 'internal: canonical path missing' if canonical.nil?

          if ephemeral?(canonical)
            raise ParameterException,
                  "ephemeral reference: #{source.inspect} resolves under a " \
                  'temporary root (C2/R10: it does not survive the ' \
                  'producing process). Remedy: attach with mode "copy" to ' \
                  'promote the bytes into the dossier store, or cite a ' \
                  'durable artifact (job-tree result file, var/records ' \
                  'file) instead. Ephemeral refs are never registered ' \
                  'silently.'
          end

          { 'class' => 'durable', 'job_tree' => job_tree?(canonical) }
        end

        def ephemeral?(canonical)
          EPHEMERAL_ROOTS.any? do |root|
            LLM::Sandbox.inside?(canonical, root)
          end
        end

        # R10 durable (job tree): a persisted var/jobs/<Workflow>/<task>/
        # directory whose result file and/or .info sidecar exist on disk.
        def job_tree?(canonical)
          dir = File.dirname(canonical)
          parts = dir.split(File::SEPARATOR)
          jobs_idx = parts.rindex { |p| p == 'jobs' }
          return false unless jobs_idx

          wf = parts[jobs_idx + 1]
          task = parts[jobs_idx + 2]
          base = parts[0..jobs_idx + 2].join(File::SEPARATOR)
          return false unless wf && task && File.directory?(base)

          stem = File.basename(canonical).sub(/\.[^.]+\z/, '')
          result_like = Dir.children(base).any? do |e|
            e == stem || e == "#{stem}.info" || e.start_with?("#{stem}.")
          end
          result_like
        end

        # -------------------------------------------------------------
        # Item parsing
        # -------------------------------------------------------------

        # parse_item!(item, index) -> normalized item Hash with keys:
        # source, slot, name, mode, caption, declared (Hash), replace
        def parse_item!(raw, index)
          unless raw.is_a?(Hash)
            raise ParameterException,
                  "items[#{index}] must be an object with source/name/mode " \
                  "(got #{raw.class})"
          end
          where = "items[#{index}]"

          source = raw['source'].to_s
          if source.strip.empty?
            raise ParameterException, "#{where}: source is required"
          end
          if raw['base_path']
            # base_path is retired from the public item schema: relative
            # sources resolve against the working project below, and a
            # stale base_path would silently relocate the source.
            raise ParameterException,
                  "#{where}: base_path is not part of the item schema; " \
                  'relative sources resolve against the working project ' \
                  '(the process cwd), and absolute sources are used as-is'
          end
          resolved = if source.start_with?('/')
                       LLM::Sandbox.resolve_path(source)[:canonical_path] || source
                     else
                       # Relative source: resolve against the WORKING
                       # PROJECT — the same base the sandbox authorize!
                       # call uses (root: Dir.pwd). Resolution is not a
                       # grant: authorize_read! still applies the full
                       # grant policy to the resolved absolute path, so
                       # a relative spelling that escapes the working
                       # project is rejected there, never silently
                       # authorized by this resolution.
                       LLM::Sandbox.resolve_path(source, base_path: Dir.pwd)[:canonical_path] ||
                         source
                     end
          source = resolved

          mode = (raw['mode'] || 'copy').to_s
          unless MODES.include?(mode)
            raise ParameterException,
                  "#{where}: mode must be one of #{MODES.inspect} (got #{mode.inspect})"
          end

          slot = raw['slot'].to_s
          if slot.strip.empty?
            raise ParameterException,
                  "#{where}: slot is required (the evidence area name, e.g. 'data')"
          end

          name = raw['name'].to_s
          if name.strip.empty?
            name = File.basename(source)
            raise ParameterException, "#{where}: cannot derive name from #{source.inspect}" if name.empty?
          end

          ITEM_TEXT_FIELDS.each do |field|
            next unless raw[field]

            Research::Tasks.reject_placeholder_text!(raw[field], "#{where} #{field}")
          end

          declared = {}
          %w[script parameters inputs receipt].each do |key|
            next unless raw[key]

            val = raw[key]
            if val.is_a?(String)
              Research::Tasks.reject_placeholder_text!(val, "#{where} declared_#{key}")
            elsif val.is_a?(Hash) || val.is_a?(Array)
              json = JSON.generate(val)
              Research::Tasks.reject_placeholder_text!(json, "#{where} declared_#{key}")
            end
            declared[key] = val
          end

          { 'source' => source, 'slot' => slot, 'name' => name,
            'mode' => mode, 'caption' => raw['caption'],
            'note' => raw['note'], 'declared' => declared,
            'replace' => Research::Tasks.truthy?(raw['replace']) }
        end

        # -------------------------------------------------------------
        # Read-time integrity observation (C4/R12)
        # -------------------------------------------------------------

        # Per-attachment integrity findings in check shape (shared by
        # dossier_capture's corruption gate and dossier_check):
        # [{ 'key', 'category' => copy_corrupted|copy_missing|
        #                     reference_missing|reference_changed,
        #   'detail', 'expected', 'observed' }]

        def attachment_integrity_findings(record, dir)
          findings = []
          (record['attachments'] || {}).each do |key, info|
            next unless info.is_a?(Hash)

            if info['mode'] == 'reference'
              source = info['source'].to_s
              unless File.file?(source)
                findings << { 'key' => key,
                              'category' => 'reference_missing',
                              'detail' => "source #{source} no longer exists",
                              'expected' => 'existing source',
                              'observed' => 'missing' }
                next
              end
              actual = StoreBytes.digest(source)
              next if actual == info['digest']

              findings << { 'key' => key, 'category' => 'reference_changed',
                            'detail' => "source #{source} hashes to " \
                                        "#{actual}, recorded #{info['digest']}",
                            'expected' => info['digest'],
                            'observed' => actual }
            else
              view = File.join(Layout.evidence_dir(dir), key)
              unless File.file?(view)
                findings << { 'key' => key, 'category' => 'copy_missing',
                              'detail' => "retained view #{view} missing",
                              'expected' => 'retained copy file',
                              'observed' => 'missing' }
                next
              end
              actual = StoreBytes.digest(view)
              next if actual == info['digest']

              findings << { 'key' => key, 'category' => 'copy_corrupted',
                            'detail' => "retained bytes hash to #{actual}, " \
                                          "recorded #{info['digest']}",
                            'expected' => info['digest'],
                            'observed' => actual }
            end
          end
          findings
        end

        def observed_integrity(entry, dir)

          mode = entry['mode'] || 'copy'
          if mode == 'reference'
            source = entry['source'].to_s
            unless File.file?(source)
              return { 'state' => 'unavailable',
                       'detail' => "referenced source no longer exists: #{source}" }
            end
            actual = StoreBytes.digest(source)
            if actual == entry['digest']
              { 'state' => 'ok',
                'detail' => 'referenced source still hashes to the recorded digest' }
            else
              { 'state' => 'changed',
                'detail' => "referenced source changed: recorded " \
                            "#{entry['digest']} but the current source hashes " \
                            'to ' + actual + '; current bytes are NOT the ' \
                            'historical evidence and are never substituted'
              }
            end
          else
            # Copy mode: the retained bytes are the digest-addressed OBJECT,
            # not the current-revision view (a view legitimately carries the
            # CURRENT revision's attachment; replacing an attachment must not
            # read as corruption of historical revisions).
            obj = Layout.object_path(dir, entry['digest'])
            unless File.file?(obj)
              return { 'state' => 'unavailable',
                       'detail' => "retained evidence object missing: #{obj} " \
                                   '(run dossier_check for a full mechanical ' \
                                   'integrity report)' }
            end
            actual = StoreBytes.digest(obj)
            if actual == entry['digest']
              { 'state' => 'ok', 'detail' => 'retained bytes hash to the recorded digest' }
            else
              { 'state' => 'changed',
                'detail' => "retained evidence corrupted: recorded " \
                            "#{entry['digest']} but the bytes on disk hash to " \
                            + actual +
                            '; run dossier_check for a full mechanical ' \
                            'integrity report' }
            end
          end
        end

        # Text-like test: valid UTF-8 heuristic (bounded head bytes).
        def text_like?(bytes)
          head = bytes.bytesize > 4096 ? bytes.byteslice(0, 4096) : bytes
          head.dup.force_encoding(Encoding::UTF_8).valid_encoding?
        rescue StandardError
          false
        end

        def detected_type(bytes, name)
          return 'text' if text_like?(bytes)

          ext = File.extname(name.to_s).downcase.delete_prefix('.')
          { 'tsv' => 'tabular', 'csv' => 'tabular', 'json' => 'json',
            'pdf' => 'pdf', 'png' => 'image', 'jpg' => 'image',
            'jpeg' => 'image', 'svg' => 'image', 'gz' => 'archive',
            'zip' => 'archive' }.fetch(ext, 'binary')
        end
      end
    end
end
