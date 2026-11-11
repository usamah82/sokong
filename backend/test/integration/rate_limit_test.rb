require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "the sixth sign-up from one address is limited and an enrolment is not" do
    hashes = 0
    original = Account.method(:digest_password)
    Account.define_singleton_method(:digest_password) do |password|
      hashes += 1
      original.call(password)
    end

    5.times do |index|
      post "/accounts", params: account_body(email: "person-#{index}@example.com"), as: :json
      assert_response :created
    end
    assert_equal 5, hashes
    assert_equal 5, Account.count

    assert_no_difference -> { Account.count } do
      post "/accounts", params: account_body(email: "person-5@example.com"), as: :json
    end
    assert_equal 5, hashes
    assert_rate_limited

    post "/enrolments", params: enrolment_body, as: :json
    assert_response :created

    travel 1.hour + 1.second do
      post "/accounts", params: account_body(email: "person-6@example.com"), as: :json
    end
    assert_response :created
    assert_equal 6, hashes
  ensure
    Account.define_singleton_method(:digest_password) { |password| original.call(password) } if original
  end

  test "a public client cannot refresh the sign-up allowance with X-Forwarded-For" do
    5.times do |index|
      post "/accounts",
        params: account_body(email: "forward-#{index}@example.com"),
        headers: { "REMOTE_ADDR" => "203.0.113.5", "X-Forwarded-For" => "198.51.100.#{index + 1}" },
        as: :json
      assert_response :created
    end

    assert_no_difference -> { Account.count } do
      post "/accounts",
        params: account_body(email: "forward-5@example.com"),
        headers: { "REMOTE_ADDR" => "203.0.113.5", "X-Forwarded-For" => "198.51.100.99" },
        as: :json
    end
    assert_rate_limited

    post "/accounts",
      params: account_body(email: "forward-6@example.com"),
      headers: { "REMOTE_ADDR" => "203.0.113.6", "X-Forwarded-For" => "198.51.100.99" },
      as: :json
    assert_response :created
  end

  test "the eleventh sign-in and confirmation from one address change nothing" do
    post "/accounts", params: account_body, as: :json
    perform_enqueued_jobs
    token = ActionMailer::Base.deliveries.last.body.to_s[/token=([^&\s]+)/, 1]
    Rails.cache.clear

    10.times do
      post "/account_verifications", params: { token: "wrong-#{SecureRandom.hex(4)}" }, as: :json
      assert_response :unprocessable_content
    end
    assert_nil Account.last.email_confirmed_at

    post "/account_verifications", params: { token: token }, as: :json
    assert_rate_limited
    assert_nil Account.last.reload.email_confirmed_at

    travel 1.hour + 1.second do
      post "/account_verifications", params: { token: token }, as: :json
    end
    assert_response :no_content

    10.times do
      post "/sessions", params: { email: "missing-#{SecureRandom.hex(4)}@example.com", password: "not the password" }, as: :json
      assert_response :unauthorized
    end

    assert_no_difference -> { AuthToken.count } do
      post "/sessions", params: { email: "Siti@Example.com", password: "correct horse battery staple" }, as: :json
    end
    assert_rate_limited

    travel 15.minutes + 1.second do
      post "/sessions", params: { email: "Siti@Example.com", password: "correct horse battery staple" }, as: :json
    end
    assert_response :ok
    assert response.parsed_body["token"]
  end

  private
    def account_body(**overrides)
      {
        email: "Siti@Example.com",
        password: "correct horse battery staple",
        password_confirmation: "correct horse battery staple"
      }.merge(overrides)
    end

    def enrolment_body
      {
        on_behalf: false,
        consent_text: "client sentence that must be ignored",
        enroler_contact: "+60 12-345 6789",
        place_name: "Kampung Baru",
        family_phone: "",
        how_to_find: " ",
        help: [],
        other_help: "",
        latitude: -90,
        longitude: 180,
        members: [ { role: "head", name: "Siti", gender: "unspecified" } ]
      }
    end

    def assert_rate_limited
      assert_response :too_many_requests
      error = response.parsed_body.fetch("error")
      assert_equal "RATE_LIMITED", error["code"]
      assert_equal "Too many attempts. Try again later.", error["message"]
      assert_equal({}, error["details"])
    end
end
