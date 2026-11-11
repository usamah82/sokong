class EnrolmentMailer < ApplicationMailer
  def invitation(email)
    mail to: email, subject: "Sokong enrolment"
  end
end
