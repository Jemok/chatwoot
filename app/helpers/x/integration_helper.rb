module X::IntegrationHelper
  PKCE_REDIS_KEY = 'x_oauth_req'.freeze

  # Stash the OAuth 1.0a request-token secret + originating account id
  # in Redis (keyed by the public oauth_token) so the X-issued callback
  # — which only echoes oauth_token + oauth_verifier — can recover both.
  def store_request_token_context(oauth_token, oauth_token_secret, account_id)
    Redis::Alfred.set(
      request_token_redis_key(oauth_token),
      "#{oauth_token_secret}|#{account_id}",
      ex: 10.minutes.to_i
    )
  end

  def fetch_request_token_context(oauth_token)
    raw = Redis::Alfred.get(request_token_redis_key(oauth_token))
    return [nil, nil] if raw.blank?

    Redis::Alfred.delete(request_token_redis_key(oauth_token))
    secret, account_id = raw.split('|', 2)
    [secret, account_id.to_i]
  end

  def request_token_redis_key(oauth_token)
    "#{PKCE_REDIS_KEY}::#{oauth_token}"
  end
end
