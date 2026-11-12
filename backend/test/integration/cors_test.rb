require "test_helper"

class CorsTest < ActionDispatch::IntegrationTest
  test "the nuxt dev server may call the enrolment routes" do
    get "/enrolments", headers: { "Origin" => "http://localhost:3001" }

    assert_response :unauthorized
    assert_equal "http://localhost:3001", response.headers["Access-Control-Allow-Origin"]
  end

  test "another origin is not allowed" do
    get "/enrolments", headers: { "Origin" => "https://example.com" }

    assert_response :unauthorized
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "the health check still succeeds" do
    get "/up"

    assert_response :success
  end
end
