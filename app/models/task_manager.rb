class TaskManager < ActiveRecord::Base
  belongs_to :paper
  has_many :phases, -> { order :id }

  after_initialize :initialize_defaults

  def tasks
    phases.map(&:tasks).flatten
  end
  private

  def initialize_defaults
    self.phases = Phase.default_phases if phases.blank?
  end
end
