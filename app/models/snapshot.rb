#
# Snapshot(s) are intended to represent a snapshot of something in the system
# at a given point in time. The point in time is determined by the major and
# minor verison of the paper at the time of the snapshot.
#
# For example, after a paper is submitted several tasks are snapshotted. This
# lays the foundation for allowing users to view the history of those tasks as
# well to provide them a way to view differences between different versions
# of a task.
#
class Snapshot < ActiveRecord::Base
  belongs_to :source, polymorphic: true
  belongs_to :paper

  validates :paper, presence: true
  validates :source, presence: true
  validates :major_version, presence: true
  validates :minor_version, presence: true

  after_initialize :set_key, if: :new_record?

  scope :attachments, -> { where(source_type: "Attachment") }
  scope :figures, -> { attachments.where("contents ->> 'name' = 'figure'") }
  scope :supporting_information_files, lambda {
    attachments.where("contents ->> 'name' = 'supporting-information-file'")
  }
  scope :adhoc_attachments, lambda {
    attachments.where("contents ->> 'name' = 'adhoc-attachment'")
  }

  def source=(new_source)
    super
    set_key
  end

  def get_property(name)
    contents["children"].find do |property|
      property["name"] == name
    end.try(:fetch, "value")
  end

  private

  def set_key
    self.key = source.try(:snapshot_key)
  end
end
