class RequestRateLimit
  RULES = {
    "accounts" => { limit: 5, period: 1.hour },
    "sessions" => { limit: 10, period: 15.minutes },
    "account_verifications" => { limit: 10, period: 1.hour }
  }.freeze

  def self.allow?(bucket, ip)
    rule = RULES.fetch(bucket)
    count = Rails.cache.increment("rate-limit:#{bucket}:#{ip}", 1, expires_in: rule[:period])
    count.nil? || count <= rule[:limit]
  end
end
