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

    Account.register!(email: @email.to_s.strip, password: @password)
  end

  private
    def collect
      return if defined?(@errors)

      @errors = []
      email = @email.to_s
      if email.strip.empty?
        reject("email", "Email is required", "is required")
      elsif email.length > 254 || !email.match?(EMAIL)
        reject("email", "Email is invalid", "is invalid")
      elsif Account.exists?(email_normalized: email.strip.downcase(:fold))
        reject("email", "Email has already been taken", "has already been taken")
      end

      if @password.blank?
        reject("password", "Password is required", "is required")
      elsif @password.length < 12
        reject("password", "Password is too short", "is too short")
      end

      if @confirmation.blank?
        reject("password_confirmation", "Password confirmation is required", "is required")
      elsif @password.present? && @password != @confirmation
        reject("password_confirmation", "Password confirmation does not match", "does not match")
      end
    end

    def reject(field, message, detail)
      @errors << { field: field, message: message, detail: detail }
    end
end
