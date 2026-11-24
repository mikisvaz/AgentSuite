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
#   - reference validation: require an existing regular file outside
#     temporary roots and record its observed digest.
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
        def validate_reference!(source, canonical)
          if canonical && File.directory?(canonical)
            raise ParameterException,
                  "broken reference: #{source.inspect} is a directory " \
                  '(C1/R7: a result ref must name one concrete artifact — ' \
                  'one regular file — on persistent storage); attach regular ' \
                  'files one by one'
          end
          unless canonical && File.file?(canonical)
            raise ParameterException,
                  "broken reference: #{source.inspect} does not resolve to " \
                  'an existing regular file (C1/R7: a result ref must name ' \
                  'one concrete artifact on persistent storage)'
          end

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

          true
        end

        def ephemeral?(canonical)
          EPHEMERAL_ROOTS.any? do |root|
            LLM::Sandbox.inside?(canonical, root)
          end
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

        # Check live references with the grants of the current caller.
        def reference_integrity(entry)
          source = authorize_read!(entry.fetch('source'))
          return { 'state' => 'unavailable', 'detail' => "referenced source no longer exists: #{source}", 'reason' => 'missing' } unless File.file?(source)

          digest_integrity(entry.fetch('digest'), StoreBytes.digest(source))
        rescue Errno::ENOENT => e
          { 'state' => 'unavailable', 'detail' => e.message, 'reason' => 'missing' }
        rescue ParameterException, Errno::EACCES => e
          { 'state' => 'unavailable', 'detail' => e.message, 'reason' => 'inaccessible' }
        end

        def digest_integrity(expected, observed)
          if expected == observed
            { 'state' => 'ok', 'detail' => 'bytes match the recorded digest' }
          else
            { 'state' => 'changed', 'detail' => "content hashes to #{observed}, expected #{expected}", 'observed' => observed }
          end
        end

        def copy_findings(dir, record)
          record.fetch('attachments', {}).filter_map do |key, entry|
            next if entry.is_a?(Hash) && entry['mode'] == 'reference'

            expected = Store.attachment_view_digest(entry)
            path = Layout.object_path(dir, expected)
            actual = File.file?(path) ? StoreBytes.digest(path) : nil
            next if actual == expected

            { 'category' => actual ? 'copy_corrupted' : 'copy_missing',
              'detail' => "retained copy #{key.inspect} hashes to #{actual || 'MISSING'}, expected #{expected}",
              'expected' => expected, 'observed' => actual || 'missing' }
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
