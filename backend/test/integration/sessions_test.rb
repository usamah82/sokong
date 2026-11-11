require "test_helper"
require "digest"

class SessionsTest < ActionDispatch::IntegrationTest
  test "a confirmed account signs in and the token lasts until sign-out" do
    account = sign_up_and_confirm

    assert_no_enqueued_emails do
      assert_difference -> { AuthToken.count } => 1 do
        post "/sessions", params: { email: "  SITI@example.com ", password: "correct horse battery staple" }, as: :json
      end
    end

    assert_response :ok
    body = response.parsed_body
    assert_equal %w[account token], body.keys.sort
    assert_equal %w[email id role], body["account"].keys.sort
    assert_equal account.id, body.dig("account", "id")
    assert_equal "Siti@Example.com", body.dig("account", "email")
    assert_equal "submitter", body.dig("account", "role")

    raw = body["token"]
    stored = AuthToken.find_by!(account_id: account.id)
    assert_equal Digest::SHA256.hexdigest(raw), stored.token_digest
    assert_not_equal raw, stored.token_digest

    travel 30.days do
      delete "/sessions", headers: { "Authorization" => "Bearer #{raw}" }
    end
    assert_response :no_content
    assert_empty response.body
    assert_not AuthToken.exists?(account_id: account.id)

    delete "/sessions", headers: { "Authorization" => "Bearer #{raw}" }
    assert_sign_in_required
  end

  test "an unconfirmed account with the right password creates no token" do
    post "/accounts", params: account_body, as: :json
    account = Account.last

    assert_no_enqueued_emails do
      assert_no_difference -> { AuthToken.count } do
        post "/sessions", params: { email: "Siti@Example.com", password: "correct horse battery staple" }, as: :json
      end
    end

    assert_response :unauthorized
    assert_equal "UNAUTHENTICATED", response.parsed_body.dig("error", "code")
    assert_equal "Confirm your email to sign in", response.parsed_body.dig("error", "message")
    assert_nil account.reload.email_confirmed_at
  end

  test "an unknown email and a wrong password use the same response" do
    sign_up_and_confirm

    unknown = nil
    wrong = nil
    assert_no_difference -> { AuthToken.count } do
      post "/sessions", params: { email: "missing@example.com", password: "correct horse battery staple" }, as: :json
      unknown = response.parsed_body
      post "/sessions", params: { email: "Siti@Example.com", password: "not the password" }, as: :json
      wrong = response.parsed_body
    end

    assert_response :unauthorized
    assert_equal unknown, wrong
    assert_equal "UNAUTHENTICATED", wrong.dig("error", "code")
    assert_equal "Email or password is wrong", wrong.dig("error", "message")
    assert_not_includes response.body, "missing@example.com"
  end

  test "a wrong password on an unconfirmed account hides that the email exists" do
    post "/accounts", params: account_body, as: :json

    unknown = nil
    assert_no_difference -> { AuthToken.count } do
      post "/sessions", params: { email: "missing@example.com", password: "not the password" }, as: :json
      unknown = response.parsed_body
      post "/sessions", params: { email: "Siti@Example.com", password: "not the password" }, as: :json
    end

    assert_response :unauthorized
    assert_equal unknown, response.parsed_body
    assert_equal "Email or password is wrong", response.parsed_body.dig("error", "message")
    assert_not_includes response.body, "Siti@Example.com"
    assert_not_includes response.body, "Confirm your email to sign in"
  end

  test "a null byte in the password is a wrong sign-in for a known or unknown email" do
    sign_up_and_confirm

    assert_no_difference -> { AuthToken.count } do
      post "/sessions", params: { email: "Siti@Example.com", password: "correct horse\0battery" }, as: :json
      assert_response :unauthorized
      assert_equal "Email or password is wrong", response.parsed_body.dig("error", "message")

      post "/sessions", params: { email: "missing@example.com", password: "correct horse\0battery" }, as: :json
      assert_response :unauthorized
      assert_equal "Email or password is wrong", response.parsed_body.dig("error", "message")
    end
  end

  test "a second sign-in and a failed sign-in leave the other token usable" do
    sign_up_and_confirm
    first = sign_in
    second = sign_in

    post "/sessions", params: { email: "Siti@Example.com", password: "not the password" }, as: :json
    assert_response :unauthorized
    assert_equal 2, AuthToken.count

    delete "/sessions", headers: { "Authorization" => "Bearer #{first}" }
    assert_response :no_content
    assert_equal 1, AuthToken.count

    delete "/sessions", headers: { "Authorization" => "Bearer #{second}" }
    assert_response :no_content
    assert_equal 0, AuthToken.count
  end

  test "a confirmation token is not a session and a session token is not a confirmation" do
    post "/accounts", params: account_body, as: :json
    perform_enqueued_jobs
    confirmation = ActionMailer::Base.deliveries.last.body.to_s[/token=([^&\s]+)/, 1]
    post "/account_verifications", params: { token: confirmation }, as: :json
    raw = sign_in

    delete "/sessions", headers: { "Authorization" => "Bearer #{confirmation}" }
    assert_sign_in_required
    assert_equal 1, AuthToken.count

    post "/account_verifications", params: { token: raw }, as: :json
    assert_response :unprocessable_content
    assert_equal "Confirmation link is invalid", response.parsed_body.dig("error", "message")
  end

  test "a non-string email or password is a wrong sign-in" do
    sign_up_and_confirm

    [ { email: nil, password: "correct horse battery staple" },
      { email: 12, password: "correct horse battery staple" },
      { email: "Siti@Example.com", password: nil } ].each do |params|
      assert_no_difference -> { AuthToken.count } do
        post "/sessions", params: params, as: :json
      end
      assert_response :unauthorized
      assert_equal "Email or password is wrong", response.parsed_body.dig("error", "message")
    end
  end

  test "only a bearer token can sign out" do
    sign_up_and_confirm
    raw = sign_in

    delete "/sessions", headers: { "Authorization" => raw }
    assert_sign_in_required

    delete "/sessions", headers: { "Authorization" => "Basic #{raw}" }
    assert_sign_in_required
    assert_equal 1, AuthToken.count

    delete "/sessions", headers: { "Authorization" => "Bearer #{raw}" }
    assert_response :no_content
  end

  test "a missing token is sign-in required" do
    delete "/sessions"
    assert_sign_in_required
  end

  private
    def account_body
      {
        email: "Siti@Example.com",
        password: "correct horse battery staple",
        password_confirmation: "correct horse battery staple"
      }
    end

    def sign_up_and_confirm
      post "/accounts", params: account_body, as: :json
      perform_enqueued_jobs
      token = ActionMailer::Base.deliveries.last.body.to_s[/token=([^&\s]+)/, 1]
      post "/account_verifications", params: { token: token }, as: :json
      assert_response :no_content
      Account.last
    end

    def sign_in
      post "/sessions", params: { email: "Siti@Example.com", password: "correct horse battery staple" }, as: :json
      assert_response :ok
      response.parsed_body.fetch("token")
    end

    def assert_sign_in_required
      assert_response :unauthorized
      assert_equal "UNAUTHENTICATED", response.parsed_body.dig("error", "code")
      assert_equal "Sign in is required", response.parsed_body.dig("error", "message")
    end
end
