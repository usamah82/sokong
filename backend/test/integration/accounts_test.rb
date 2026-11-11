require "test_helper"
require "digest"

class AccountsTest < ActionDispatch::IntegrationTest
  test "a sign-up returns an opaque token and a submitter, even when a role is sent" do
    assert_difference -> { Account.count } => 1, -> { AuthToken.count } => 1 do
      post "/accounts", params: account_body(role: "worker"), as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal %w[account token], body.keys.sort
    token = body["token"]
    account = body["account"]

    assert_equal %w[email id role], account.keys.sort
    assert_equal "Siti@Example.com", account["email"]
    assert_equal "submitter", account["role"]
    assert_equal 36, account["id"].length
    assert_match(/\A[0-9a-f-]{36}\z/, account["id"])

    assert_operator token.length, :>=, 32
    assert_not_includes token, "."
    assert_not_includes token, "Siti"
    assert_not_equal Digest::SHA256.hexdigest(token), token

    stored = Account.find(account["id"])
    assert_equal "submitter", stored.role
    assert_equal "Siti@Example.com", stored.email
    assert_equal "siti@example.com", stored.email_normalized
    assert stored.authenticate("correct horse battery staple")
    assert_equal Digest::SHA256.hexdigest(token), stored.auth_tokens.sole.token_digest

    foreign_key = ActiveRecord::Base.connection.foreign_keys("locality_assignments")
      .find { |key| key.column == "account_id" }
    assert_equal "accounts", foreign_key&.to_table
  end

  test "a mismatch, a short password, a duplicate email, or a missing field creates no account" do
    Account.register!(email: "siti@example.com", password: "correct horse battery staple")

    bodies = [
      account_body(password_confirmation: "correct horse battery staples"),
      account_body(password: "too-short", password_confirmation: "too-short"),
      account_body(email: "SITI@example.com"),
      account_body.except(:email),
      account_body.except(:password),
      account_body.except(:password_confirmation),
      account_body(email: "   ")
    ]

    bodies.each do |body|
      assert_no_difference -> { Account.count + AuthToken.count } do
        post "/accounts", params: body, as: :json
      end

      assert_response :unprocessable_content
      error = JSON.parse(response.body).fetch("error")
      assert_equal "VALIDATION_ERROR", error["code"]
      assert error["message"].present?
      assert error["details"].present?
    end

    assert_equal 1, Account.count
  end

  private
    def account_body(**extra)
      {
        email: "Siti@Example.com",
        password: "correct horse battery staple",
        password_confirmation: "correct horse battery staple"
      }.merge(extra)
    end
end
