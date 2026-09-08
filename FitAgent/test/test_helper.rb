require 'test/unit'
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))
require 'scout-ai'
require 'FitAgent/scenarios'
require 'FitAgent/scoring'
require 'FitAgent/runner'
require 'FitAgent/evolve'
require 'FitAgent/agent_chat'
require 'FitAgent/proposer'

# Repo-level default target (the shipped example): registers the scenario
# catalogue and the default message rules the tests materialize. Loading a
# DIFFERENT target (see test_target.rb) replaces it; nothing in lib/ names
# the example.
FitAgent::Scenarios.load(File.expand_path('../examples/computeruse-patch/target.yaml', __dir__)) unless ENV['FITAGENT_NO_DEFAULT_TARGET']
