class AccountsController < ApplicationController
  wrap_parameters false

  def create
    registration = AccountRegistration.new(params)
    if (error = registration.error_envelope)
      render json: { error: error }, status: :unprocessable_content
    else
      account = registration.save
      render json: account_json(account), status: :created
    end
  rescue ActiveRecord::RecordNotUnique
    render json: {
      error: {
        code: "VALIDATION_ERROR",
        message: "Email has already been taken",
        details: { email: [ "has already been taken" ] }
      }
    }, status: :unprocessable_content
  end

  private
    def account_json(account)
      {
        account: {
          id: account.id,
          email: account.email,
          role: account.role
        }
      }
    end
end
