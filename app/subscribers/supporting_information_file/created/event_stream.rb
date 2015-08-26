class SupportingInformationFile::Created::EventStream < EventStreamSubscriber

  def channel
    private_channel_for(record.paper)
  end

  def payload
    SupportingInformationFileSerializer.new(record).to_json
  end

end
