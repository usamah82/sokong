class EnrolmentInvitationDeliveryJob < ActionMailer::MailDeliveryJob
  # Arguments can be an email, a head, a place, or a visit time. Leave them out of the log.
  self.log_arguments = false
end
