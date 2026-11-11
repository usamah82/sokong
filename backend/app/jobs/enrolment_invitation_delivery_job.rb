class EnrolmentInvitationDeliveryJob < ActionMailer::MailDeliveryJob
  # The only argument is the enroler's email. Active Job logs arguments by default.
  self.log_arguments = false
end
