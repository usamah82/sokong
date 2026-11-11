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

    assert_no_difference -> { AuthToken.count } do
      post "/sessions", params: { email: "Siti@Example.com", password: "correct horse battery staple" }, as: :json
    end

    assert_response :unauthorized
    assert_equal "UNAUTHENTICATED", response.parsed_body.dig("error", "code")
    assert_equal "Confirm your email to sign in", response.parsed_body.dig("error", "message")
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

    def assert_sign_in_required
      assert_response :unauthorized
      assert_equal "UNAUTHENTICATED", response.parsed_body.dig("error", "code")
      assert_equal "Sign in is required", response.parsed_body.dig("error", "message")
    end
end
