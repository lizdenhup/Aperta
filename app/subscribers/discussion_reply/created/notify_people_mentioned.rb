# Send a Notification to people mentioned in a forum reply
# rubocop:disable ClassAndModuleChildren
class DiscussionReply::Created::NotifyPeopleMentioned
  def self.call(_event_name, event_data)
    reply = event_data[:record]

    people_mentioned = UserMentions.new(reply.body,
                                        reply.replier).people_mentioned

    people_mentioned.each do |mentionee|
      create_notification(reply, mentionee) if reply.discussion_topic.has_participant?(mentionee)
    end
  end

  def self.create_notification(reply, mentionee)
    reply.notifications.where({
      paper: reply.discussion_topic.paper,
      user: mentionee,
      parent_id: reply.discussion_topic.id,
      parent_type: 'DiscussionTopic'
    }).first_or_create!
  end
end