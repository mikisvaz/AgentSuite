require 'scout'
require 'scout-ai'

# Native dossier tasks (WO-3+), self-contained on scout-essentials
# primitives (design D4: no Workspace require, no helper merge).
#
# The store root is FIXED project-relative: <working project>/research,
# resolved from Dir.pwd inside each task body at EXECUTION time (never
# captured into job inputs or Step build time). Task declarations live
# in ordinary files under lib/Research/tasks/, reopened through this
# module — workflow.rb holds the bootstrap only.
module Research
  extend Workflow
end

require_relative 'lib/Research/tasks/common'
require_relative 'lib/Research/tasks/dossier_create'
require_relative 'lib/Research/tasks/dossier_list'
require_relative 'lib/Research/tasks/dossier_read'
require_relative 'lib/Research/tasks/dossier_update'
require_relative 'lib/Research/tasks/evidence_attach'
require_relative 'lib/Research/tasks/evidence_read'
require_relative 'lib/Research/tasks/dossier_check'
require_relative 'lib/Research/tasks/dossier_history'
require_relative 'lib/Research/tasks/dossier_capture'
