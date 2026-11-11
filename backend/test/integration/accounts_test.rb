require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  test "a sign-up returns a submitter and no token, even when a role is sent" do
    assert_enqueued_emails 1 do
      assert_difference -> { Account.count } => 1 do
        post "/accounts", params: account_body(role: "worker"), as: :json
      end
    end

    assert_response :created
    body = response.parsed_body
    assert_equal [ "account" ], body.keys
    account = body["account"]

    assert_equal %w[email id role], account.keys.sort
    assert_equal "Siti@Example.com", account["email"]
    assert_equal "submitter", account["role"]
    assert_equal 36, account["id"].length
    assert_match(/\A[0-9a-f-]{36}\z/, account["id"])

    stored = Account.find(account["id"])
    assert_equal "submitter", stored.role
    assert_equal "Siti@Example.com", stored.email
    assert_equal "siti@example.com", stored.email_normalized
    assert_nil stored.email_confirmed_at
    assert stored.authenticate("correct horse battery staple")
    assert_not ActiveRecord::Base.connection.table_exists?("auth_tokens")

    foreign_key = ActiveRecord::Base.connection.foreign_keys("locality_assignments")
      .find { |key| key.column == "account_id" }
    assert_equal "accounts", foreign_key&.to_table
  end

  test "a mismatch, a short password, a duplicate email, or a missing field creates no account" do
    account = Account.register!(email: "siti@example.com", password: "correct horse battery staple")
    account.update!(email_confirmed_at: Time.current)

    cases = [
      [ account_body(password_confirmation: "correct horse battery staples"), "password_confirmation", "does not match" ],
      [ account_body(password: "too-short", password_confirmation: "too-short"), "password", "is too short" ],
      [ account_body(email: "SITI@example.com"), "email", "has already been taken" ],
      [ account_body(email: "  SITI@example.com  "), "email", "has already been taken" ],
      [ account_body(email: "not-an-email"), "email", "is invalid" ],
      [ account_body(email: 12), "email", "is invalid" ],
      [ account_body.except(:email), "email", "is required" ],
      [ account_body.except(:password), "password", "is required" ],
      [ account_body.except(:password_confirmation), "password_confirmation", "is required" ],
      [ account_body(email: "   "), "email", "is required" ]
    ]

    cases.each do |body, field, detail|
      assert_no_difference -> { Account.count } do
        post "/accounts", params: body, as: :json
      end

      assert_response :unprocessable_content
      error = response.parsed_body.fetch("error")
      assert_equal "VALIDATION_ERROR", error["code"]
      assert_equal [ detail ], error.dig("details", field), body.inspect
    end

    assert_equal 1, Account.count
  end

  test "a duplicate that passes the pre-check still returns 422" do
    Account.register!(email: "siti@example.com", password: "correct horse battery staple")

    original = Account.method(:find_by)
    Account.define_singleton_method(:find_by) { |*args, **kwargs| nil }
    assert_no_difference -> { Account.count } do
      post "/accounts", params: account_body(email: "SITI@example.com"), as: :json
    end
  ensure
    Account.define_singleton_method(:find_by) { |*args, **kwargs, &block| original.call(*args, **kwargs, &block) }

    assert_response :unprocessable_content
    assert_equal [ "has already been taken" ], response.parsed_body.dig("error", "details", "email")
    assert_equal 1, Account.count
  end

  test "eleven characters is rejected and twelve characters is accepted" do
    short = "a" * 11
    long_enough = "a" * 12

    assert_no_difference -> { Account.count } do
      post "/accounts", params: account_body(password: short, password_confirmation: short), as: :json
    end
    assert_response :unprocessable_content
    assert_equal "VALIDATION_ERROR", response.parsed_body.dig("error", "code")
    assert_equal [ "is too short" ], response.parsed_body.dig("error", "details", "password")

    assert_difference -> { Account.count } => 1 do
      post "/accounts", params: account_body(
        email: "twelve@example.com",
        password: long_enough,
        password_confirmation: long_enough
      ), as: :json
    end
    assert_response :created
    assert_equal [ "account" ], response.parsed_body.keys
    assert_equal "submitter", response.parsed_body.dig("account", "role")
    assert_nil Account.find(response.parsed_body.dig("account", "id")).email_confirmed_at
  end

  test "a padded email is stored trimmed and an overlong email is too long" do
    post "/accounts", params: account_body(email: "  Siti@Example.com  "), as: :json

    assert_response :created
    assert_equal "Siti@Example.com", response.parsed_body.dig("account", "email")
    stored = Account.find(response.parsed_body.dig("account", "id"))
    assert_equal "siti@example.com", stored.email_normalized
    assert_nil stored.email_confirmed_at

    overlong = "#{"a" * 243}@example.com"
    assert_equal 255, overlong.length
    assert_no_difference -> { Account.count } do
      post "/accounts", params: account_body(email: overlong), as: :json
    end
    assert_response :unprocessable_content
    assert_equal [ "is too long" ], response.parsed_body.dig("error", "details", "email")

    accepted = "#{"b" * 242}@example.com"
    assert_equal 254, accepted.length
    assert_difference -> { Account.count } => 1 do
      post "/accounts", params: account_body(email: accepted), as: :json
    end
    assert_response :created
    assert_equal accepted, response.parsed_body.dig("account", "email")
  end

  test "a non-string, a null byte, or a password over 72 bytes returns a validation error" do
    boundary = "a" * 72
    assert_difference -> { Account.count } => 1 do
      post "/accounts", params: account_body(
        email: "boundary@example.com",
        password: boundary,
        password_confirmation: boundary
      ), as: :json
    end
    assert_response :created
    assert_equal [ "account" ], response.parsed_body.keys

    multibyte = "é" * 40
    assert_equal 40, multibyte.length
    assert_operator multibyte.bytesize, :>, 72

    cases = [
      [ account_body(password: 12, password_confirmation: "correct horse battery staple"), "is invalid" ],
      [ account_body(password: "correct horse\0battery", password_confirmation: "correct horse\0battery"), "is invalid" ],
      [ account_body(password: "a" * 73, password_confirmation: "a" * 73), "is too long" ],
      [ account_body(password: multibyte, password_confirmation: multibyte), "is too long" ]
    ]

    cases.each do |body, detail|
      assert_no_difference -> { Account.count } do
        post "/accounts", params: body, as: :json
      end

      assert_response :unprocessable_content
      assert_equal [ detail ], response.parsed_body.dig("error", "details", "password"), body.inspect
    end
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
