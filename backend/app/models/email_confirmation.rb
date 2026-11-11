require "digest"

class EmailConfirmation < ApplicationRecord
  belongs_to :account

  def self.redeem(token)
    return unless token.is_a?(String)
    return if token.empty? || token.include?("\0")

    record = find_by(token_digest: Digest::SHA256.hexdigest(token))
    return if record.nil? || record.expires_at <= Time.current

    transaction do
      record.account.update!(email_confirmed_at: Time.current)
      record.destroy!
    end
    true
  end
end
