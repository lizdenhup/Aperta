# Manage creating scheduled events
class ScheduledEventFactory
  attr_reader :due_datetime, :template

  def initialize(object, template)
    @due_datetime = object.due_datetime
    @template = template
  end

  def schedule_events
    return unless due_datetime
    return schedule_new_events unless owned_serviceable_events.exists?
    update_scheduled_events
  end

  private

  def owned_serviceable_events
    due_datetime.scheduled_events.serviceable
  end

  def dispatch_date(event)
    return nil unless due_datetime
    (due_datetime.due_at + event[:dispatch_offset].days).beginning_of_hour
  end

  def reschedule(event, template)
    new_date = dispatch_date(template)

    if event.completed?
      if event.dispatch_at < new_date
        new_event = event.dup
        event.reactivate
        event.dispatch_at = new_date
        new_event.save
      end
    end

    event.dispatch_at = new_date
    event.save
  end

  def schedule_new_events
    template.each do |event|
      ScheduledEvent.create name: event[:name],
                            dispatch_at: dispatch_date(event),
                            due_datetime: due_datetime
    end
  end

  def update_scheduled_events
    template.each do |entry|
      # try to reschedule an already existing version of this event.
      # if more than one exist, reschedule the one with with the most recent
      # dispatch_at date
      event = owned_serviceable_events.where(name: entry[:name]).order(dispatch_at: :desc).first
      reschedule event, entry if event.present?
    end
  end
end
