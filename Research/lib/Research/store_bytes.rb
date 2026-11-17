# Byte-identity support for the dossier store: digests and atomic writes.
#
# Content identity inside the store is always SHA-256 hex of the exact
# bytes. Every address exposed to consumers is (record path, digest): the
# path locates, the digest pins (D2 — citation-grade addresses are record
# paths + digests, never job paths).
#
# write_atomic is the ONLY sanctioned writer inside the store root:
#   - a tmp file in the TARGET's own directory (guaranteed same
#     filesystem, so the final File.rename is a true atomic rename);
#   - fsync of the file before the rename (crash durability);
#   - optional fsync of the parent directory after the rename;
#   - tmp files are swept on failure.
#
# This deliberately does NOT reuse Open.sensible_write: scout-essentials
# stages tmp files under a global Open.sensible_write_dir (cwd-sensitive
# pathmap) and renames across into the target — cross-filesystem when the
# store root is not on the same filesystem as that staging area, which
# silently degrades the atomicity guarantee into open-copy-close
# (FileUtils.mv semantics). The old records engine used it; the dossier
# store cannot (copied-and-narrowed per the WO-2 header: reuse of retired
# machinery is by copying into new modules, not by requiring it).
#
# write_atomic raises WriteError on any failure and never leaves a torn
# final path: the target either does not exist yet, or fully holds the old
# bytes, or fully holds the new bytes.

require 'digest'
require 'fileutils'

module Research
  module StoreBytes
    class WriteError < StandardError; end

    TMP_PREFIX = '.tmp-store-'.freeze

    class << self
      def digest(path)
        Digest::SHA256.file(path).hexdigest
      end

      def digest_bytes(bytes)
        Digest::SHA256.hexdigest(bytes)
      end

      # write_atomic(path, bytes)  -> digest of the written bytes
      # write_atomic(path, bytes, sync_dir: false)  (true by default)
      def write_atomic(path, bytes, sync_dir: true)
        dir = File.dirname(path)
        raise WriteError, "not a directory: #{dir.inspect}" unless File.directory?(dir)

        tmp = File.join(dir, "#{TMP_PREFIX}#{File.basename(path)}.#{Process.pid}.#{rand(1_000_000)}")
        begin
          File.open(tmp, 'wb') do |f|
            f.write(bytes)
            f.flush
            f.fsync
          end
          File.rename(tmp, path)
        rescue StandardError => e
          FileUtils.rm_f(tmp) if File.exist?(tmp)
          raise WriteError, "atomic write failed for #{path}: #{e.class}: #{e.message}"
        end

        fsync_dir(dir) if sync_dir
        digest_bytes(bytes)
      end

      def fsync_dir(dir)
        fd = IO.sysopen(dir)
        io = IO.for_fd(fd)
        begin
          io.fsync
        ensure
          io.close
        end
      rescue StandardError
        # Directory fsync is a durability optimization; failure to fsync a
        # directory (platform-dependent) never fails a correct write.
      end

      # Read exactly the file's bytes; raises StoreBytes::WriteError
      # subclasses never — plain IO errors propagate to the caller.
      def read(path)
        File.binread(path)
      end
    end
  end
end
