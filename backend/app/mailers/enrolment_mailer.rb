class EnrolmentMailer < ApplicationMailer
  self.delivery_job = EnrolmentInvitationDeliveryJob

  def invitation(email)
    mail to: email, subject: "Sokong enrolment"
  end
end
