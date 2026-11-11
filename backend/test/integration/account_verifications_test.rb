require "test_helper"
require "digest"

class AccountVerificationsTest < ActionDispatch::IntegrationTest
  test "sign-up queues one confirmation and a valid token confirms the email" do
    assert_enqueued_emails 1 do
      post "/accounts", params: account_body, as: :json
    end

    assert_response :created
    assert_nil response.parsed_body["token"]
    account = Account.find(response.parsed_body.dig("account", "id"))
    assert_nil account.email_confirmed_at

    perform_enqueued_jobs
    delivered = ActionMailer::Base.deliveries.sole
    assert_equal [ "Siti@Example.com" ], delivered.to
    assert_equal "Confirm your Sokong email", delivered.subject
    body = delivered.text_part&.body&.to_s || delivered.body.to_s
    token = body[/http:\/\/localhost:3001\/confirm\?token=([^&\s]+)/, 1]
    assert token
    assert_equal "#{CONFIRMATION_COPY}\nhttp://localhost:3001/confirm?token=#{token}", body.strip

    confirmation = EmailConfirmation.find_by!(account_id: account.id)
    assert_equal Digest::SHA256.hexdigest(token), confirmation.token_digest
    assert_not_equal token, confirmation.token_digest
    assert_in_delta 24.hours.from_now, confirmation.expires_at, 5

    post "/account_verifications", params: { token: token }, as: :json

    assert_response :no_content
    assert_empty response.body
    assert_not_nil account.reload.email_confirmed_at
    assert_not EmailConfirmation.exists?(account_id: account.id)
    assert_not ActiveRecord::Base.connection.table_exists?("auth_tokens")
  end

  test "a second use, a wrong token, and an expired token confirm nothing" do
    post "/accounts", params: account_body, as: :json
    token = confirmation_token

    post "/account_verifications", params: { token: token }, as: :json
    assert_response :no_content
    confirmed_at = Account.last.email_confirmed_at

    post "/account_verifications", params: { token: token }, as: :json
    assert_invalid_link
    assert_equal confirmed_at, Account.last.reload.email_confirmed_at

    post "/accounts", params: account_body(email: "other@example.com"), as: :json
    other = Account.find_by!(email: "other@example.com")
    post "/account_verifications", params: { token: "not-a-real-token" }, as: :json
    assert_invalid_link
    assert_nil other.reload.email_confirmed_at

    post "/accounts", params: account_body(email: "later@example.com"), as: :json
    later = Account.find_by!(email: "later@example.com")
    expired = confirmation_token
    travel 24.hours + 1.second do
      post "/account_verifications", params: { token: expired }, as: :json
    end
    assert_invalid_link
    assert_nil later.reload.email_confirmed_at
  end

  test "repeating sign-up for an unconfirmed email replaces the password and the link" do
    post "/accounts", params: account_body, as: :json
    assert_response :created
    first = confirmation_token
    account = Account.last

    assert_no_difference -> { Account.count } do
      assert_enqueued_emails 1 do
        post "/accounts", params: account_body(
          password: "another horse battery",
          password_confirmation: "another horse battery"
        ), as: :json
      end
    end

    assert_response :created
    assert_equal account.id, response.parsed_body.dig("account", "id")
    account.reload
    assert account.authenticate("another horse battery")
    assert_not account.authenticate("correct horse battery staple")
    assert_nil account.email_confirmed_at
    assert_equal 1, EmailConfirmation.where(account_id: account.id).count

    post "/account_verifications", params: { token: first }, as: :json
    assert_invalid_link
    assert_nil account.reload.email_confirmed_at

    post "/account_verifications", params: { token: confirmation_token }, as: :json
    assert_response :no_content
    assert_not_nil account.reload.email_confirmed_at
  end

  test "a confirmed email is rejected and the stored password stays" do
    post "/accounts", params: account_body, as: :json
    token = confirmation_token
    post "/account_verifications", params: { token: token }, as: :json
    account = Account.last
    digest = account.password_digest

    assert_no_enqueued_emails do
      assert_no_difference -> { Account.count } do
        post "/accounts", params: account_body(
          email: "  SITI@example.com ",
          password: "another horse battery",
          password_confirmation: "another horse battery"
        ), as: :json
      end
    end

    assert_response :unprocessable_content
    assert_equal "Email has already been taken", response.parsed_body.dig("error", "message")
    assert_equal [ "has already been taken" ], response.parsed_body.dig("error", "details", "email")
    account.reload
    assert_equal digest, account.password_digest
    assert account.authenticate("correct horse battery staple")
  end

  test "an unconfirmed repeat matches a padded email of a different case" do
    post "/accounts", params: account_body, as: :json
    first = confirmation_token
    account = Account.last

    assert_no_difference -> { Account.count } do
      assert_enqueued_emails 1 do
        post "/accounts", params: account_body(
          email: "  SITI@example.com ",
          password: "another horse battery",
          password_confirmation: "another horse battery"
        ), as: :json
      end
    end

    assert_response :created
    assert_equal account.id, response.parsed_body.dig("account", "id")
    assert_equal "Siti@Example.com", account.reload.email
    assert account.authenticate("another horse battery")
    assert_not account.authenticate("correct horse battery staple")
    assert_equal 1, EmailConfirmation.where(account_id: account.id).count

    post "/account_verifications", params: { token: first }, as: :json
    assert_invalid_link

    post "/account_verifications", params: { token: confirmation_token }, as: :json
    assert_response :no_content
  end

  test "a rejected repeat leaves the unconfirmed account and its link" do
    post "/accounts", params: account_body, as: :json
    token = confirmation_token
    account = Account.last
    digest = account.password_digest

    [
      account_body(password_confirmation: "correct horse battery staples"),
      account_body(password: "too-short", password_confirmation: "too-short")
    ].each do |body|
      assert_no_enqueued_emails do
        assert_no_difference -> { Account.count } do
          post "/accounts", params: body, as: :json
        end
      end
      assert_response :unprocessable_content
    end

    assert_equal digest, account.reload.password_digest
    post "/account_verifications", params: { token: token }, as: :json
    assert_response :no_content
    assert_not_nil account.reload.email_confirmed_at
  end

  test "a token confirms during the last second of its day" do
    post "/accounts", params: account_body, as: :json
    token = confirmation_token
    expires_at = EmailConfirmation.last.expires_at

    travel_to expires_at - 1.second do
      post "/account_verifications", params: { token: token }, as: :json
    end

    assert_response :no_content
    assert_not_nil Account.last.email_confirmed_at
  end

  test "a wrong token leaves the issued link usable" do
    post "/accounts", params: account_body, as: :json
    token = confirmation_token

    post "/account_verifications", params: { token: "not-a-real-token" }, as: :json
    assert_invalid_link
    assert_nil Account.last.email_confirmed_at

    post "/account_verifications", params: { token: token }, as: :json
    assert_response :no_content
    assert_not_nil Account.last.email_confirmed_at
  end

  test "the confirmation token and the email stay out of the logs" do
    previous_logger = ActiveJob::Base.logger
    previous_mail_logger = ActionMailer::Base.logger
    assert_equal false, AccountConfirmationDeliveryJob.log_arguments
    job_log = StringIO.new
    mail_log = StringIO.new
    ActiveJob::Base.logger = ActiveSupport::Logger.new(job_log)
    ActionMailer::Base.logger = ActiveSupport::Logger.new(mail_log)

    post "/accounts", params: account_body, as: :json
    perform_enqueued_jobs
    token = ActionMailer::Base.deliveries.last.body.to_s[/token=([^&\s]+)/, 1]

    assert_not_includes job_log.string, token
    assert_not_includes job_log.string, "Siti@Example.com"
    assert_not_includes mail_log.string, token
    assert_not_includes mail_log.string, "Siti@Example.com"

    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      .filter(token: token, email: "Siti@Example.com")
    assert_equal "[FILTERED]", filtered[:token]
    assert_equal "[FILTERED]", filtered[:email]
  ensure
    ActiveJob::Base.logger = previous_logger
    ActionMailer::Base.logger = previous_mail_logger
  end

  test "a sign-up that read an unconfirmed account does not replace a password after confirmation" do
    post "/accounts", params: account_body, as: :json
    account = Account.find(response.parsed_body.dig("account", "id"))
    digest = account.password_digest
    registration = AccountRegistration.new(
      email: "Siti@Example.com",
      password: "another horse battery",
      password_confirmation: "another horse battery"
    )
    assert_nil registration.error_envelope

    post "/account_verifications", params: { token: confirmation_token }, as: :json
    assert_response :no_content

    assert_no_enqueued_emails do
      assert_raises(ActiveRecord::RecordNotUnique) { registration.save }
    end
    account.reload
    assert_equal digest, account.password_digest
    assert account.authenticate("correct horse battery staple")
  end

  test "a raised enqueue error still saves the account and returns 201" do
    previous = ActiveJob::Base.queue_adapter
    adapter = RaisingQueueAdapter.new
    ActiveJob::Base.queue_adapter = adapter

    assert_difference -> { Account.count } => 1 do
      post "/accounts", params: account_body, as: :json
    end

    assert_equal 1, adapter.attempts
    assert_response :created
    stored = Account.find(response.parsed_body.dig("account", "id"))
    assert stored.authenticate("correct horse battery staple")
    assert_nil stored.email_confirmed_at
  ensure
    ActiveJob::Base.queue_adapter = previous
  end

  CONFIRMATION_COPY = "Confirm this email address to sign in to Sokong. If you did not sign up, ignore this message."

  class RaisingQueueAdapter
    attr_reader :attempts

    def initialize
      @attempts = 0
    end

    def enqueue(*)
      @attempts += 1
      raise "queue down"
    end

    def enqueue_at(*)
      raise "queue down"
    end
  end

  private
    def account_body(**overrides)
      {
        email: "Siti@Example.com",
        password: "correct horse battery staple",
        password_confirmation: "correct horse battery staple"
      }.merge(overrides)
    end

    def confirmation_token
      perform_enqueued_jobs
      body = ActionMailer::Base.deliveries.last.body.to_s
      body[/http:\/\/localhost:3001\/confirm\?token=([^&\s]+)/, 1]
    end

    def assert_invalid_link
      assert_response :unprocessable_content
      assert_equal "Confirmation link is invalid", response.parsed_body.dig("error", "message")
      assert_equal "VALIDATION_ERROR", response.parsed_body.dig("error", "code")
    end
end
