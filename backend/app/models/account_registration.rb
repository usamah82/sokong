class AccountRegistration
  EMAIL = URI::MailTo::EMAIL_REGEXP

  def initialize(params)
    @email = params[:email]
    @password = params[:password]
    @confirmation = params[:password_confirmation]
  end

  def error_envelope
    collect
    return if @errors.empty?

    {
      code: "VALIDATION_ERROR",
      message: @errors.first[:message],
      details: @errors.each_with_object({}) do |error, details|
        (details[error[:field]] ||= []) << error[:detail]
      end
    }
  end

  def save
    raise ArgumentError, error_envelope[:message] if error_envelope

    digest = Account.digest_password(@password)
    raw = nil
    account = Account.transaction do
      saved = persist(digest)
      raw = saved.issue_confirmation!
      saved
    end
    queue_confirmation(account.email, raw)
    account
  end

  private
    def persist(digest)
      if @existing
        @existing.reload
        raise ActiveRecord::RecordNotUnique if @existing.email_confirmed_at

        @existing.update!(password_digest: digest)
        @existing
      else
        Account.create!(email: @email_address, password_digest: digest, role: "submitter")
      end
    end

    def queue_confirmation(email, raw)
      AccountMailer.confirmation(email, raw).deliver_later
    rescue StandardError => error
      Rails.logger.info("Account confirmation was not queued: #{error.class}")
    end

    def collect
      return if defined?(@errors)

      @errors = []
      collect_email
      collect_password
      collect_confirmation
    end

    def collect_email
      if @email.nil?
        reject("email", "Email is required", "is required")
        return
      end
      unless @email.is_a?(String)
        reject("email", "Email is invalid", "is invalid")
        return
      end

      cleaned = @email.strip
      if cleaned.empty?
        reject("email", "Email is required", "is required")
      elsif cleaned.length > 254
        reject("email", "Email is too long", "is too long")
      elsif !cleaned.match?(EMAIL)
        reject("email", "Email is invalid", "is invalid")
      else
        existing = Account.find_by(email_normalized: cleaned.downcase(:fold))
        if existing&.email_confirmed_at
          reject("email", "Email has already been taken", "has already been taken")
        else
          @existing = existing
          @email_address = cleaned
        end
      end
    end

    def collect_password
      collect_secret(@password, "password", "Password")
    end

    def collect_confirmation
      collect_secret(@confirmation, "password_confirmation", "Password confirmation")
      return if @errors.any? { |error| error[:field] == "password" || error[:field] == "password_confirmation" }
      return unless @password.is_a?(String) && @confirmation.is_a?(String)
      return if @password == @confirmation

      reject("password_confirmation", "Password confirmation does not match", "does not match")
    end

    def collect_secret(value, field, label)
      if value.nil?
        reject(field, "#{label} is required", "is required")
      elsif !value.is_a?(String)
        reject(field, "#{label} is invalid", "is invalid")
      elsif value.blank?
        reject(field, "#{label} is required", "is required")
      elsif value.include?("\0")
        reject(field, "#{label} is invalid", "is invalid")
      elsif value.bytesize > 72
        reject(field, "#{label} is too long", "is too long")
      elsif value.length < 12
        reject(field, "#{label} is too short", "is too short")
      end
    end

    def reject(field, message, detail)
      @errors << { field: field, message: message, detail: detail }
    end
end
