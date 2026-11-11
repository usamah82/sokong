class SessionsController < ApplicationController
  wrap_parameters false

  def create
    session = AccountSession.new(params)
    if (error = session.error_envelope)
      render json: { error: error }, status: :unauthorized
    else
      token = session.save
      render json: { token: token, account: account_json(session.account) }, status: :ok
    end
  end

  def destroy
    record = AuthToken.find_by(token_digest: digest_for(bearer_token))
    if record
      record.destroy!
      head :no_content
    else
      require_account
    end
  end

  private
    def account_json(account)
      { id: account.id, email: account.email, role: account.role }
    end
end
