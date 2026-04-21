class Webhooks::LinkedinController < ActionController::API
  # GET /webhooks/linkedin?challengeCode=<...>
  # LinkedIn handshake: respond with HMAC-SHA256(challengeCode, clientSecret) hex digest.
  def verify
    challenge = params[:challengeCode].to_s
    if challenge.blank? || client_secret.blank?
      head :bad_request
      return
    end

    digest = OpenSSL::HMAC.hexdigest('SHA256', client_secret, challenge)
    render json: { challengeCode: challenge, challengeResponse: digest }
  end

  # POST /webhooks/linkedin
  # LinkedIn signs the raw request body with HMAC-SHA256 and base64-encodes it
  # in the `X-LI-Signature` header. Verify, then enqueue.
  def events
    raw_body = request.raw_post

    unless valid_signature?(raw_body)
      Rails.logger.warn('[LinkedIn webhook] signature mismatch')
      head :unauthorized
      return
    end

    payload = JSON.parse(raw_body)
    Rails.logger.info("LINKEDIN_WEBHOOK_RAW: #{payload.to_json}")
    ::Webhooks::LinkedinEventsJob.perform_later(payload)
    head :ok
  rescue JSON::ParserError => e
    Rails.logger.warn("[LinkedIn webhook] invalid JSON: #{e.message}")
    head :bad_request
  end

  private

  def valid_signature?(raw_body)
    signature = request.headers['X-LI-Signature'].to_s
    return false if signature.blank? || client_secret.blank?

    expected = Base64.strict_encode64(OpenSSL::HMAC.digest('SHA256', client_secret, raw_body))
    ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end

  def client_secret
    @client_secret ||= GlobalConfigService.load('LINKEDIN_APP_SECRET', '')
  end
end
