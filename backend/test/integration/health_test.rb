require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "GET /up reports the process can serve traffic" do
    get rails_health_check_path

    assert_response :success
  end
end
