# Frozen-semantics guard: the F/E/C materialized fixture digests must equal
# the pre-decoupling values (tmp/digests-before.txt, captured with the
# catalogue still inside lib/FitAgent/scenarios.rb). Manifest digests are
# computed over the materialized fixture bytes, so this pins the catalogue
# move to examples/computeruse-patch/catalogue.rb as byte-identical.
require File.expand_path('../../test_helper', __dir__)
require 'tmpdir'

class TestTargetDigests < Test::Unit::TestCase
  EXPECTED = {
    'C01' => '744e1796f196c692420321fa400f51e8',
    'C02' => 'f6f9af520ff44eab4e111662a0fb42d4',
    'E01' => '6c0c8a4f90097c59eafdd08b4d40163c',
    'E02' => '299884b7cff5148df87161ad5ef7e9d5',
    'E03' => 'e2797829f80449b8b6c8043fa693027d',
    'E04' => '81e670ea4e8c98fa36aea92d2e988bae',
    'E05' => '848ee96f964e4e6615daa1e1ce2d452f',
    'E05b' => '296533c0a9b633ef78ed7af97d540f93',
    'E06' => '7fe19c2b6d9ab8fb81345d2526c92f01',
    'F01' => 'e9a95a8b4b49a2e5e84c9377eedf9e3d',
    'F02' => '3062228bcf1a0657ea48cf98d8d40598',
    'F03' => '5442750af135f760cfac8be20d07f499',
    'F04' => '3fec543e761f0cbff0020cfc62348338',
    'F05' => 'ea3c30fe0de0edf3ed941b06a0991b40',
    'F06' => '8651cda4edfddc7220bf160072ea2c3f',
    'F07' => '75dc204fb583f9c3c7a0fa0d0ae1f316',
    'F08' => '640484b0f8093d76ec671159eb80b964'
  }.freeze
  SET_DIGEST = '4942cacdda221373327b296526c4155f'.freeze

  def test_materialized_fixture_digests_unchanged_by_decoupling
    Dir.mktmpdir('fitagent-digests') do |tmp|
      manifest = FitAgent::Scenarios.materialize(File.join(tmp, 'set'))
      got = manifest['scenarios'].each_with_object({}) { |s, h| h[s['id']] = s['digest'] }
      assert_equal EXPECTED, got
      assert_equal SET_DIGEST, manifest['set_digest']
      assert_equal 'patch-v2', manifest['version']
    end
  end
end
