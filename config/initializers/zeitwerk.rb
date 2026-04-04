# frozen_string_literal: true

# Collapse the repositories directory so classes like RoleRepository
# are accessible at the top level rather than Repositories::RoleRepository
Rails.autoloaders.main.collapse("#{Rails.root}/app/services/repositories")
