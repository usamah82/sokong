class AccountVerificationsController < ApplicationController
  wrap_parameters false

  def create
    if EmailConfirmation.redeem(params[:token])
      head :no_content
    else
      render json: {
        error: {
          code: "VALIDATION_ERROR",
          message: "Confirmation link is invalid",
          details: {}
        }
      }, status: :unprocessable_content
    end
  end
end
