# Per-type ID allocation for the dossier store.
#
# Every ID is root-local and per-type sequential with a two-letter prefix
# and three digits, growing naturally past 999: Q-001, C-001, H-001,
# Q-1000 ... Allocation is serialized at the ROOT level (a single
# <root>/meta/ids lock guards all types' counters) through Open.lock —
# scout-essentials' flock-based lock — so concurrent processes allocate
# disjoint IDs and no ID is ever reused: inside the lock the counter file
# is read, +1, written back atomically (StoreBytes.write_atomic), and the
# file for the new ID must not exist (a re-registration attempt of a
# reused slot is a hard error, and the counter write happens only after
# that check, so a rejected duplicate does not burn an ID... except a
# legitimately raced one, which cannot happen because of the lock).
#
# Allocation NEVER depends on the caller's cwd: all paths derive from the
# absolute resolved root (D1). The counter file lives at
# <root>/meta/ids/<type>.counter.
#
# Open.lock is copied-by-use from scout-essentials (still a runtime
# dependency, just not through the retired records module), per the WO-2
# header: reuse of retired machinery is by copying into the new modules.

require 'fileutils'
require 'scout'
require_relative 'store_bytes'

module Research
  module Ids
    class Error < StandardError; end

    TYPES = { 'question' => 'Q', 'claim' => 'C', 'hypothesis' => 'H' }.freeze
    WIDTH = 3

    class << self
      def valid_type?(type)
        TYPES.key?(type)
      end

      def format_id(type, number)
        "#{TYPES.fetch(type)}-#{format("%0#{WIDTH}d", number)}"
      end

      # allocate(root, type) -> id (String)
      # Serialized across all types by the single root lock; the counter is
      # persisted atomically; the target dossier directory must not already
      # contain the ID (when it does, the caller is racing a completed
      # allocation with a stale counter — a hard error, never silent reuse).
      def allocate(root, type)
        raise Error, "unknown dossier type #{type.inspect} (known: #{TYPES.keys.join(', ')})" unless valid_type?(type)

        root = root.to_s
        id_dir = File.join(root, 'meta', 'ids')
        FileUtils.mkdir_p(id_dir)

        Open.lock(File.join(id_dir, 'allocate.lock')) do
          counter_path = File.join(id_dir, "#{type}.counter")
          next_number = read_counter(counter_path) + 1
          id = format_id(type, next_number)
          dossier_dir = Layout.dossier_dir(root, type, id)
          if File.exist?(dossier_dir)
            raise Error, "ID allocation collision: #{id} already exists at " \
                         "#{dossier_dir} (counter value #{read_counter(counter_path)}); " \
                         'this indicates a corrupted counter — refusing to reuse an ID'
          end
          StoreBytes.write_atomic(counter_path, next_number.to_s)
          id
        end
      end

      def read_counter(counter_path)
        return 0 unless File.exist?(counter_path)
        text = StoreBytes.read(counter_path).strip
        return 0 if text.empty?
        Integer(text, 10)
      end
    end
  end
end

require_relative 'layout'
