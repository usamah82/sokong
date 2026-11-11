class AccountConfirmationDeliveryJob < ActionMailer::MailDeliveryJob
  # Arguments include the raw confirmation token.
  self.log_arguments = false
end
