class JournalFactory
  def self.create(journal_params)
    journal = Journal.new(journal_params)
    new(journal).create
  end

  def self.ensure_default_roles_and_permissions_exist(journal)
    new(journal).ensure_default_roles_and_permissions_exist
  end

  def initialize(journal)
    @journal = journal
  end

  def create
    @journal.save!
    ensure_default_roles_and_permissions_exist
    @journal
  end

  def ensure_default_roles_and_permissions_exist
    Role.ensure_exists('Author', journal: @journal, participates_in: [Task, Paper]) do |role|
      role.ensure_permission_exists(:view, applies_to: 'Task', states: ['*'])
      role.ensure_permission_exists(:view, applies_to: 'Paper', states: ['*'])
      role.ensure_permission_exists(:view, applies_to: 'PlosBilling::BillingTask', states: ['*'])
    end

    Role.ensure_exists('Reviewer', journal: @journal, participates_in: [Task, Paper]) do |role|
      role.ensure_permission_exists(:view, applies_to: 'Task', states: ['*'])
      role.ensure_permission_exists(:view, applies_to: 'Paper', states: ['*'])
    end

    Role.ensure_exists('Staff Admin', journal: @journal) do |role|
      role.ensure_permission_exists(:administer, applies_to: 'Journal', states: ['*'])
      role.ensure_permission_exists(:manage_workflow, applies_to: 'Paper', states: ['*'])
      role.ensure_permission_exists(:view, applies_to: 'Paper', states: ['*'])
      role.ensure_permission_exists(:view, applies_to: 'Task', states: ['*'])
      role.ensure_permission_exists(:view, applies_to: 'PlosBilling::BillingTask', states: ['*'])
    end

    Role.ensure_exists('Publishing Services and Production Staff', journal: @journal) do |role|
      role.ensure_permission_exists(:manage_workflow, applies_to: 'Paper', states: ['*'])
      role.ensure_permission_exists(:view, applies_to: 'Paper', states: ['*'])
      role.ensure_permission_exists(:view, applies_to: 'Task', states: ['*'])
      role.ensure_permission_exists(:view, applies_to: 'PlosBilling::BillingTask', states: ['*'])
    end
  end
end
