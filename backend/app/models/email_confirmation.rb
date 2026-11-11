require "digest"

class EmailConfirmation < ApplicationRecord
  belongs_to :account

  def self.redeem(token)
    return unless token.is_a?(String)
    return if token.empty? || token.include?("\0")

    digest = Digest::SHA256.hexdigest(token)
    confirmed = false
    transaction do
      record = find_by(token_digest: digest)
      if record && record.expires_at > Time.current
        record.account.update!(email_confirmed_at: Time.current)
        record.destroy!
        confirmed = true
      end
    end
    confirmed
  end
end
