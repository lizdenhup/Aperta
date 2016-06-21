# Attachment represents a generic file/resource. It is intended to be used
# as a base-class.
#
# Note: the subclass(es) should mount the uploader as :file and keep any
# custom processing/version logic with it. Only generic aspects of an
# attachment should be pushed up to this base-class.
class Attachment < ActiveRecord::Base
  include EventStream::Notifiable
  include ProxyableResource

  # writes to `token` attr on create
  # `regenerate_token` for new token
  has_secure_token

  belongs_to :owner, polymorphic: true
  belongs_to :paper

  validates :owner, presence: true

  # Where the attachment is placed on S3 is partially determined by the symbol
  # that is given to `mount_uploader`. ProxyableResource (and it's URL helper)
  # assumes the AttachmentUploader will be mounted as `attachment`. To prevent a
  # production S3 data migration we're aliasing `attachment` to `file`.
  def attachment
    file
  end

  def attachment=(attach)
    self.file = attach
  end

  def filename
    self[:file]
  end

  # This is a hash used for recognizing changes in file contents; if
  # the file doens't exist, or if we can't connect to amazon, minimal
  # harm comes from returning nil instead. The error thrown is,
  # unfortunately, not wrapped by carrierwave.
  def file_hash
    file.file.attributes[:etag]
  rescue
    nil
  end

  def done?
    status == 'done'
  end

  def owner=(new_owner)
    if new_owner.is_a?(Paper)
      self.paper = new_owner
    elsif new_owner.respond_to?(:paper)
      self.paper = new_owner.paper
    end
    super
  end

  def task
    if owner_type == 'Task'
      owner
    end
  end
end
