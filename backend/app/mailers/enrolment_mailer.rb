class EnrolmentMailer < ApplicationMailer
  self.delivery_job = EnrolmentInvitationDeliveryJob

  MONTHS = %w[January February March April May June July August September October November December].freeze

  def self.utc_label(time)
    utc = time.utc
    format("%d %s %d at %02d:%02d UTC", utc.day, MONTHS.fetch(utc.month - 1), utc.year, utc.hour, utc.min)
  end

  def invitation(email)
    mail to: email, subject: "Sokong enrolment"
  end

  def visit_set(email, head, place, visit_time)
    @sentence = "A visit is set for #{head} at #{place}. The visit time is #{visit_time}."
    mail to: email, subject: "Sokong visit"
  end

  def visit_changed(email, head, place, visit_time)
    @sentence = "The visit time for #{head} at #{place} is now #{visit_time}."
    mail to: email, subject: "Sokong visit"
  end
end
