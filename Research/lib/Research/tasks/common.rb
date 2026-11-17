# Shared task-layer helpers for the native dossier tasks.
#
# Validation and orchestration live in the task files themselves (one
# task per file under lib/Research/tasks/); this module carries only the
# helpers shared by several tasks:
#
#   - store_root: the fixed project-relative research root
#     (File.expand_path('research', Dir.pwd)), computed on every call so
#     a Dir.chdir between dispatches retargets the store; never a job
#     input, never captured at Step-build time;
#   - input validation raising Scout exceptions (ParameterException), so
#     the exec dispatch layer returns structured error values instead of
#     crashing the tool call (LLM.call_workflow rescues ScoutException);
#   - the caller-facing document namespace: the entry document is
#     'README.md' (Manager ruling 1) and supplementary authored documents
#     live under 'supplements/'. Name checks are SECURITY validation,
#     not character allowlists (Manager ruling 4);
#   - mapping store-layer failures (Store/Ids/Layout/LineEdit errors)
#     onto ParameterException with their messages preserved;
#   - the compaction-placeholder write guard (reject_placeholder_text!):
#     transcript compaction markers must never be persisted as authored
#     content;
#   - title derivation for listings (first H1 of the entry document —
#     derived from authoritative store data, so any listing is
#     rebuildable and no index can go stale).
#
# LineEdit stays pure (Manager ruling 3): the line-edit composition
# wrapper lives in tasks/dossier_update.rb, not in line_edit.rb.

require 'scout'
require_relative '../ids'
require_relative '../layout'
require_relative '../store_bytes'
require_relative '../store'
require_relative '../line_edit'

module Research
  module Tasks
    ENTRY_DOCUMENT = Layout::DOC # 'README.md' (Manager ruling 1)
    TYPES = Ids::TYPES.keys.freeze # question, claim, hypothesis (Manager ruling 2)
    TYPE_OF_PREFIX = Ids::TYPES.invert.freeze

    # Transcript compaction markers that must never be persisted as
    # authored content (the concrete marker this environment inserts
    # into agent transcripts is '[TOOL-COMPACTION-RECORD] ...').
    PLACEHOLDER_MARKERS = ['TOOL-COMPACTION-RECORD'].freeze

    class << self
      # -------------------------------------------------------------
      # Store root (fixed project-relative, execution-time resolution)
      # -------------------------------------------------------------

      # The store root for the working project: <project>/research.
      # Computed from Dir.pwd on every call, so task bodies that call
      # this inside their execution re-target the store after a
      # Dir.chdir between dispatches. There is no config chain, no env
      # variable, no fallback: the working project IS the project.
      # Other contents of research/ are not the store's and stay
      # untouched (the store owns questions/, claims/, hypotheses/ and
      # per-dossier trees only).
      def store_root
        File.expand_path('research', Dir.pwd)
      end

      # -------------------------------------------------------------
      # Types and ids (Manager ruling 2: exactly three types)
      # -------------------------------------------------------------

      def parse_type!(type)
        unless Ids.valid_type?(type.to_s)
          raise ParameterException,
                "unknown dossier type #{type.inspect}; the type vocabulary is " \
                'exactly question, claim, hypothesis'
        end
        type.to_s
      end

      # parse_id!('Q-003') -> ['question', 'Q-003']
      def parse_id!(id)
        s = id.to_s
        m = /\A([QCH])-(\d+)\z/.match(s)
        unless m
          raise ParameterException,
                "invalid dossier id #{id.inspect}: a dossier id is <Q|C|H>-<number>, " \
                'for example Q-001'
        end
        [TYPE_OF_PREFIX.fetch(m[1]), s]
      end

      # Stable listing order: type order (question, claim, hypothesis per
      # Layout::TYPES), then numeric id within the type (Q-9 < Q-10).
      def id_sort_key(id)
        type, = parse_id!(id)
        [Layout::TYPES.index(type), id.split('-', 2)[1].to_i]
      end

      # -------------------------------------------------------------
      # Document names (Manager rulings 1 and 4)
      # -------------------------------------------------------------

      # store_document_name!(document) -> store document name.
      #
      # Accepts 'README.md' and 'supplements/<name>' (one path segment,
      # any characters the filesystem allows, spaces and non-ASCII
      # included). Rejects — with distinct, actionable messages —
      # empty/invalid-UTF-8/NUL names, absolute paths, '.'/'..'
      # traversal, evidence paths, reserved store/metadata areas, and
      # anything outside the authored-document namespace. This is
      # deliberately NOT a character allowlist; the underlying store
      # validator is narrower in shape but this layer owns the
      # security-relevant rejections.
      def store_document_name!(document)
        s = document.to_s
        if s.empty?
          raise ParameterException,
                "document must be a non-empty name (got #{document.inspect})"
        end
        unless s.valid_encoding?
          raise ParameterException, 'document name must be valid UTF-8 text'
        end
        if s.include?("\0")
          raise ParameterException, 'document name must not contain NUL bytes'
        end
        if s.start_with?('/')
          raise ParameterException,
                "document #{s.inspect} must be relative to the dossier; " \
                'absolute paths are rejected'
        end
        parts = s.split('/')
        if parts.include?('..') || parts.include?('.')
          raise ParameterException,
                "document #{s.inspect} must not contain '.' or '..' components; " \
                'traversal out of the dossier is rejected'
        end
        if s == Layout::EVIDENCE || s.start_with?("#{Layout::EVIDENCE}/")
          raise ParameterException,
                "#{s.inspect} is an evidence attachment, not an authored text " \
                'document; evidence bytes are immutable and are served by ' \
                'evidence_read, not dossier_read'
        end
        if s == Layout::STORE || s.start_with?("#{Layout::STORE}/") ||
           s == Layout::ROOT_META || s.start_with?("#{Layout::ROOT_META}/")
          raise ParameterException,
                "#{s.inspect} is a reserved store/metadata area, never an authored " \
                'document; revision records are cited through the record and ' \
                'record_digest result fields of the dossier tasks'
        end
        return s if s == Layout::DOC

        if s.start_with?("#{Layout::SUPPLEMENTS}/")
          rest = s[(Layout::SUPPLEMENTS.length + 1)..]
          if rest.empty? || rest.split('/').any?(&:empty?) || rest.end_with?('/')
            raise ParameterException,
                  "supplement path #{s.inspect} is not a usable relative " \
                  "document path under #{Layout::SUPPLEMENTS}/ " \
                  '(nested folders are supported; empty segments are not)'
          end
          return s
        end

        raise ParameterException,
              "document #{s.inspect} is not an authored document of the dossier; " \
              "authored documents are '#{ENTRY_DOCUMENT}' and " \
              "'#{Layout::SUPPLEMENTS}/<name>'"
      end

      # Store name -> caller-facing name. After the README.md rename the
      # two namespaces coincide; the mapping is kept explicit so the
      # entry document remains a named concept at the task surface.
      def public_document_name(name)
        name == Layout::DOC ? ENTRY_DOCUMENT : name
      end

      # -------------------------------------------------------------
      # Compaction-placeholder write guard
      # -------------------------------------------------------------

      def reject_placeholder_text!(text, label)
        return true unless String === text

        PLACEHOLDER_MARKERS.each do |marker|
          next unless text.include?(marker)

          raise ParameterException,
                "#{label} contains the transcript compaction marker " \
                "#{marker.inspect}: compaction placeholders are pointers, never " \
                'evidence — re-read the durable source and write the real content ' \
                'instead of persisting transcript metadata'
        end
        true
      end

      # -------------------------------------------------------------
      # Small coercions
      # -------------------------------------------------------------

      def truthy?(value)
        value == true || value.to_s == 'true'
      end

      def int!(value, label)
        case value
        when Integer
          value
        when String
          unless value =~ /\A-?\d+\z/
            raise ParameterException,
                  "#{label} must be an integer (got #{value.inspect})"
          end
          value.to_i
        when nil
          raise ParameterException, "#{label} is required"
        else
          raise ParameterException,
                "#{label} must be an integer (got #{value.class})"
        end
      end

      # First Markdown H1 ('# ...') of a document, or nil. Derived
      # purely from current authored bytes: listings rebuilt from the
      # store always re-derive it, so the title can never come from a
      # side index that could go stale.
      def title_of(text)
        text.each_line do |line|
          m = /\A#\s+(.+?)\s*\z/.match(line.chomp)
          return m[1] unless m.nil?
        end
        nil
      end

      # -------------------------------------------------------------
      # Error mapping
      # -------------------------------------------------------------

      # Store-layer failures become Scout exceptions so exec dispatch
      # returns them as values; their actionable messages are preserved.
      # ParameterException passes through untouched.
      def map_store_errors(root = nil, id = nil)
        yield
      rescue ParameterException
        raise
      rescue Store::StaleRevision, Store::Missing, Store::Drift,
             Store::Corrupt, Store::Interrupted, Store::Error,
             Ids::Error, Layout::Error, LineEdit::Error,
             StoreBytes::WriteError => e
        where = id ? " (dossier #{id} at root #{root})" : " (root #{root})"
        raise ParameterException,
              "#{e.class.name.split('::').last}: #{e.message}#{where}"
      end
    end
  end
end
