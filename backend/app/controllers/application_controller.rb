require "digest"

class ApplicationController < ActionController::API
  private
    def bearer_token
      scheme, token = request.authorization.to_s.split(" ", 2)
      token if scheme&.casecmp("Bearer")&.zero? && token.present?
    end

    def digest_for(token)
      Digest::SHA256.hexdigest(token) if token
    end

    def sign_in_required
      { code: "UNAUTHENTICATED", message: "Sign in is required", details: {} }
    end

    def current_account
      return @current_account if defined?(@current_account)

      @current_account = AuthToken.find_by(token_digest: digest_for(bearer_token))&.account
    end

    def require_account
      return if current_account

      render json: { error: sign_in_required }, status: :unauthorized
    end

    def within_rate_limit?(bucket)
      return true if RequestRateLimit.allow?(bucket, rate_limit_ip)

      render json: {
        error: {
          code: "RATE_LIMITED",
          message: "Too many attempts. Try again later.",
          details: {}
        }
      }, status: :too_many_requests
      false
    end

    def rate_limit_ip
      peer = request.remote_addr.to_s
      return request.remote_ip if peer.empty? || trusted_proxy?(peer)

      peer
    end

    def trusted_proxy?(ip)
      proxies = Rails.application.config.action_dispatch.trusted_proxies
      proxies = ActionDispatch::RemoteIp::TRUSTED_PROXIES if proxies.blank?
      proxies.any? { |proxy| proxy === ip }
    end
end
