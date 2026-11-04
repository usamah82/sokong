require Rails.root.join("lib/limit_request_body")

Rails.application.config.middleware.unshift LimitRequestBody
