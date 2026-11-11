require "digest"

class AccountSession
  def initialize(params)
    @email = params[:email]
    @password = params[:password]
  end

  def error_envelope
    open
    @failure
  end

  def account
    open
    @authenticated
  end

  def save
    raise ArgumentError, error_envelope[:message] if error_envelope

    raw = SecureRandom.urlsafe_base64(32)
    @authenticated.auth_tokens.create!(token_digest: Digest::SHA256.hexdigest(raw))
    raw
  end

  def self.dummy_digest
    @dummy_digest ||= Account.digest_password("dummy-password-for-timing")
  end

  private
    def open
      return if defined?(@authenticated)

      found = find_account
      matched = password_matches?(found)
      if matched && found.email_confirmed_at
        @authenticated = found
        @failure = nil
      elsif matched
        @authenticated = nil
        @failure = unauthenticated("Confirm your email to sign in")
      else
        @authenticated = nil
        @failure = unauthenticated("Email or password is wrong")
      end
    end

    def find_account
      return unless @email.is_a?(String)

      Account.find_by(email_normalized: @email.strip.downcase(:fold))
    end

    def password_matches?(account)
      return @matched if defined?(@matched)

      candidate = @password.is_a?(String) ? @password : ""
      @matched = if account
        account.authenticate(candidate).present?
      else
        BCrypt::Password.new(self.class.dummy_digest).is_password?(candidate)
        false
      end
    end

    def unauthenticated(message)
      { code: "UNAUTHENTICATED", message: message, details: {} }
    end
end
