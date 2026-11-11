require "digest"

class Account < ApplicationRecord
  has_secure_password

  has_one :email_confirmation, dependent: :destroy

  before_validation :assign_email_normalized

  validates :role, inclusion: { in: %w[submitter worker] }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }

  def self.register!(email:, password:)
    create!(email: email, password: password, role: "submitter")
  end

  def self.digest_password(password)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
    BCrypt::Password.create(password, cost: cost).to_s
  end

  def issue_confirmation!
    email_confirmation&.destroy!
    raw = SecureRandom.urlsafe_base64(32)
    create_email_confirmation!(
      token_digest: Digest::SHA256.hexdigest(raw),
      expires_at: 24.hours.from_now
    )
    raw
  end

  private
    def assign_email_normalized
      cleaned = email.to_s.strip
      self.email = cleaned
      self.email_normalized = cleaned.downcase(:fold)
    end
end
