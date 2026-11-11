# The invitation's only personal field is the recipient. Action Mailer's debug
# subscriber writes the encoded message, and a delivery error message can echo
# that address. Log the message id and the error class instead.
require "action_mailer/log_subscriber"
require "action_mailer/structured_event_subscriber"

module InvitationMailLog
  def deliver(event)
    message_id = event.payload[:message_id]
    exception = event.payload[:exception_object]

    info do
      if exception
        "Failed delivery of mail #{message_id} error_class=#{exception.class}"
      elsif event.payload[:perform_deliveries]
        "Delivered mail #{message_id} (#{event.duration.round(1)}ms)"
      else
        "Skipped delivery of mail #{message_id} as `perform_deliveries` is false"
      end
    end
  end
end

ActionMailer::LogSubscriber.prepend(InvitationMailLog)

module InvitationMailEvent
  def deliver(event)
    exception = event.payload[:exception_object]
    payload = {
      message_id: event.payload[:message_id],
      duration_ms: event.duration.round(2),
      perform_deliveries: event.payload[:perform_deliveries]
    }
    payload[:exception_class] = exception.class.name if exception

    emit_debug_event("action_mailer.delivered", payload)
  end
end

ActionMailer::StructuredEventSubscriber.prepend(InvitationMailEvent)
