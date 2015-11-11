stream_to_user = EventStream::StreamToUser

Subscriptions.configure do
  add 'paper:resubmitted', Paper::Resubmitted::ReopenRevisionTasks

  add 'tahi_standard_tasks/apex_delivery:updated', stream_to_user
  add 'tahi_standard_tasks/apex_delivery:delivery_succeeded',
      ApexDelivery::DeliverySucceeded::FlashSuccessMessage
end
