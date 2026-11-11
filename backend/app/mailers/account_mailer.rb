class AccountMailer < ApplicationMailer
  self.delivery_job = AccountConfirmationDeliveryJob

  def confirmation(email, token)
    @token = token
    mail to: email, subject: "Confirm your Sokong email"
  end
end
