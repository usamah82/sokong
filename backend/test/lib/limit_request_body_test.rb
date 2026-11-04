require "test_helper"

class LimitRequestBodyTest < ActiveSupport::TestCase
  setup do
    @middleware = LimitRequestBody.new(->(env) { [ 200, {}, [ env["rack.input"].read ] ] })
  end

  test "a declared length over 128 KiB is refused before the body is read" do
    input = Object.new
    input.define_singleton_method(:read) { raise "the body should not be read" }
    env = rack_env("x" * (LimitRequestBody::LIMIT + 1))
    env["rack.input"] = input

    status, headers, body = @middleware.call(env)

    assert_equal 413, status
    assert_equal "close", headers["connection"]
    assert_equal "PAYLOAD_TOO_LARGE", JSON.parse(body.join).dig("error", "code")
  end

  test "a short content length cannot hide a longer body" do
    env = rack_env("x" * (LimitRequestBody::LIMIT + 1))
    env["CONTENT_LENGTH"] = "10"

    status, = @middleware.call(env)

    assert_equal 413, status
  end

  test "a body at the limit is passed to the app" do
    payload = "y" * LimitRequestBody::LIMIT

    status, _, body = @middleware.call(rack_env(payload))

    assert_equal 200, status
    assert_equal payload, body.join
  end

  test "chunked transfer encoding is refused" do
    env = rack_env("{}")
    env["HTTP_TRANSFER_ENCODING"] = "chunked"

    status, = @middleware.call(env)

    assert_equal 413, status
  end

  private
    def rack_env(body)
      {
        "REQUEST_METHOD" => "POST",
        "rack.input" => StringIO.new(body),
        "CONTENT_LENGTH" => body.bytesize.to_s
      }
    end
end
