class LimitRequestBody
  LIMIT = 128 * 1024

  def initialize(app)
    @app = app
  end

  def call(env)
    return too_large if chunked?(env) || declared_length(env) > LIMIT

    input = env["rack.input"]
    if input
      body = capped_body(input)
      env["rack.input"] = StringIO.new(body)
      env["CONTENT_LENGTH"] = body.bytesize.to_s
    end
    @app.call(env)
  rescue BodyTooLarge
    too_large
  end

  private
    def chunked?(env)
      env["HTTP_TRANSFER_ENCODING"].to_s.downcase.include?("chunked")
    end

    def declared_length(env)
      header = env["CONTENT_LENGTH"]
      return 0 if header.nil? || header == ""

      Integer(header, 10)
    rescue ArgumentError
      0
    end

    def capped_body(input)
      data = (+"").b
      while data.bytesize <= LIMIT
        chunk = input.read(LIMIT + 1 - data.bytesize)
        break if chunk.nil? || chunk.empty?

        data << chunk
        raise BodyTooLarge if data.bytesize > LIMIT
      end
      data
    end

    def too_large
      body = JSON.generate(
        error: {
          code: "PAYLOAD_TOO_LARGE",
          message: "Payload is too large",
          details: {}
        }
      )
      [
        413,
        {
          "content-type" => "application/json; charset=utf-8",
          "content-length" => body.bytesize.to_s,
          "connection" => "close"
        },
        [ body ]
      ]
    end

  class BodyTooLarge < StandardError
  end
end
