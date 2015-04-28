class EventStreamConnection
  include Rails.application.routes.url_helpers

  # loaded into ember client via pusher-override.coffee
  def as_json(options={})
    {
      enabled: self.class.enabled?,
      host: ENV["EVENT_STREAM_WS_HOST"],
      port: ENV["EVENT_STREAM_WS_PORT"],
      auth_endpoint_path: auth_event_stream_path,
      key: Pusher.key,
      channels: default_channels
    }
  end

  def authorized?(user:, channel_name:)
    channel = ChannelNameParser.new(channel_name: channel_name)
    return true if channel.public?
    return false unless Paper.exists?(channel.get(:paper))
    return false unless user.id.to_s == channel.get(:user)
    Accessibility.new(Paper.find(channel.get(:paper))).users.include?(user)
  end

  def authenticate(channel_name:, socket_id:)
    Pusher[channel_name].authenticate(socket_id)
  end

  def default_channels
    ["system"]
  end

  def self.enabled?
    ENV["EVENT_STREAM_ENABLED"] != "false"
  end
end
