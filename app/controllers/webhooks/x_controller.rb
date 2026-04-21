# Receives X (Twitter) Account Activity webhook events.
# X uses CRC (Challenge-Response Check): on `GET` it expects a JSON body
# `{ response_token: "sha256=" + Base64(HMAC_SHA256(consumer_secret, crc_token)) }`.
# https://developer.twitter.com/en/docs/twitter-api/premium/account-activity-api/guides/securing-webhooks
class Webhooks::XController < ActionController::API
  def verify
    crc_token = params[:crc_token]
    return head :bad_request if crc_token.blank?

    secret = GlobalConfigService.load('X_CONSUMER_SECRET', '')
    return head :bad_request if secret.blank?

    digest = OpenSSL::HMAC.digest('SHA256', secret, crc_token)
    render json: { response_token: "sha256=#{Base64.strict_encode64(digest)}" }
  end

  def events
    Rails.logger.info('X webhook received events')
    payload = params.to_unsafe_hash.except(:controller, :action)
    Rails.logger.info("X_WEBHOOK_RAW: #{payload.to_json}")

    ::Webhooks::XEventsJob.perform_later(payload)
    render json: :ok
  end
end
