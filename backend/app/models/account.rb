class Account < ApplicationRecord
  has_secure_password

  before_validation :assign_email_normalized

  validates :role, inclusion: { in: %w[submitter worker] }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }

  def self.register!(email:, password:)
    create!(email: email, password: password, role: "submitter")
  end

  private
    def assign_email_normalized
      cleaned = email.to_s.strip
      self.email = cleaned
      self.email_normalized = cleaned.downcase(:fold)
    end
end
