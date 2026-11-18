# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :enroler_contact, :family_phone, :how_to_find, :other_help,
  :latitude, :longitude, :name, :description, :job, :monthly_amount,
  :phone, :number, :other_label, :assigned_workers, :origin, :notes,
  :birth_date, :absent_since, :absent_reason, :others_stay_detail, :care_for_parents_detail,
  :how_it_started, :previous_jobs, :wished_work, :skills, :school_going, :school_where, :school_travel,
  :hard_week, :who_steps_in, :children_at_home, :unsafe_detail, :need_most,
  /\Abasket\z/
]
