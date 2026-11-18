class Verification < ApplicationRecord
  belongs_to :enrolment

  STAGES = %w[who_is_here formation daily_life dynamics house needs boxes].freeze
end
