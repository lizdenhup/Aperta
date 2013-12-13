class Phase < ActiveRecord::Base
  belongs_to :task_manager
  has_many :tasks

  after_initialize :initialize_defaults

  DEFAULT_PHASE_NAMES = [
    "Needs Editor",
    "Needs Reviewer",
    "Needs Review",
    "Needs Decision"
  ]

  def self.default_phases
    DEFAULT_PHASE_NAMES.map { |name| Phase.new name: name }
  end

  private

  def initialize_defaults
    if name == 'Needs Editor' && tasks.empty?
      self.tasks << PaperAdminTask.new
      self.tasks << PaperEditorTask.new
    end
  end
end
