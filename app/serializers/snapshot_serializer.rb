class SnapshotSerializer < ActiveModel::Serializer
  attributes :id, :source_id, :source_type, :major_version, :minor_version, :contents, :sanitized_contents, :created_at

  def sanitized_contents
    object.sanitized_contents
  end
end
