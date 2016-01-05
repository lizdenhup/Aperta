##
# To see *all* subscriptions, try `rake subscriptions`!
#
# For event stream sbuscriptions, check out event_stream_subscribers.rb
#

Subscriptions.configure do
  add '.*', EventLogger
  add 'paper:submitted', Paper::Submitted::EmailCreator, Paper::Submitted::EmailAdmins, Paper::Submitted::SnapshotMetadata
  add 'paper:initially_submitted', Paper::Submitted::SnapshotMetadata
  add 'paper:resubmitted', Paper::Resubmitted::EmailEditor

  add 'discussion_reply:created', DiscussionReply::Created::EmailPeopleMentioned
  add 'discussion_participant:created', \
      DiscussionParticipant::Created::EmailNewParticipant

  add 'discussion_participant:created', Notification::Badger
  add 'discussion_participant:destroyed', Notification::Unbadger
end
