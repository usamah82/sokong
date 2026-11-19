require "test_helper"

class LooksTest < ActionDispatch::IntegrationTest
  test "a look and a note queue no mail" do
    post "/enrolments", params: {
      on_behalf: false,
      consent_text: "ignored",
      enroler_contact: "+60 12-345 6789",
      email: "siti@example.com",
      place_name: "Kampung Baru",
      members: [ { role: "head", name: "Siti", gender: "unspecified" } ]
    }, as: :json
    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    account = Account.create!(
      email: "worker-#{SecureRandom.hex(4)}@example.com",
      password: "correct horse battery staple",
      role: "worker",
      name: "Aman",
      email_confirmed_at: Time.current
    )
    LocalityAssignment.create!(account:, locality: enrolment.locality)
    post "/sessions", params: { email: account.email, password: "correct horse battery staple" }, as: :json
    token = response.parsed_body.fetch("token")
    headers = { "Authorization" => "Bearer #{token}" }

    assert_no_enqueued_emails do
      get "/enrolments/#{enrolment.id}", headers: headers
    end
    assert_response :ok

    assert_no_enqueued_emails do
      post "/enrolments/#{enrolment.id}/looks",
        params: { note: "Called the enroler, no answer" },
        headers: headers,
        as: :json
    end
    assert_response :created
  end
end
