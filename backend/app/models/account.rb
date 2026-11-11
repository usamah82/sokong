class Account < ApplicationRecord
  has_secure_password

  has_many :auth_tokens, dependent: :destroy

  before_validation :assign_email_normalized

  validates :role, inclusion: { in: %w[submitter worker] }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }

  def self.register!(email:, password:)
    transaction do
      account = create!(email: email, password: password, role: "submitter")
      raw_token = SecureRandom.urlsafe_base64(32)
      account.auth_tokens.create!(token_digest: Digest::SHA256.hexdigest(raw_token))
      [ account, raw_token ]
    end
  end

  private
    def assign_email_normalized
      cleaned = email.to_s.strip
      self.email = cleaned
      self.email_normalized = cleaned.downcase(:fold)
    end
end
