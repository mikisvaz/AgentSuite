require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path('../../../workflow', __dir__)
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

class TestClass < Test::Unit::TestCase
  def test_convert
    patch=<<-EOF
*** Begin Patch
*** Update File: [FILE]
@@
-require 'scout/gear'
-require 'scout-ai'
-require_relative '../lib/swing_trader/agent'
-require_relative '../lib/swing_trader/swing_trader'
+require 'scout/gear'
+require_relative '../lib/swing_trader/swing_trader'
*** End Patch
    EOF

    file =<<-EOF
require 'scout/gear'
require 'scout-ai'
require_relative '../lib/swing_trader/agent'
require_relative '../lib/swing_trader/swing_trader'
    EOF

    target =<<-EOF
--- a/[FILE]
+++ b/[FILE]
@@ -1,4 +1,2 @@
-require 'scout/gear'
-require 'scout-ai'
-require_relative '../lib/swing_trader/agent'
-require_relative '../lib/swing_trader/swing_trader'
+require 'scout/gear'
+require_relative '../lib/swing_trader/swing_trader'
    EOF

    filename = "patch_test_#{Process.pid}.rb"
    path = File.join(Workspace.root, filename)
    File.write(path, file)
    begin
      patch = patch.gsub('[FILE]', filename)
      target = target.gsub('[FILE]', filename)
      converted = Workspace.convert_chatgpt_patch(patch)
      assert_equal target, converted
    ensure
      File.delete(path) if File.exist?(path)
    end
  end
end

