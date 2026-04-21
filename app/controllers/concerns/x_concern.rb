require 'oauth'

module XConcern
  extend ActiveSupport::Concern

  X_SITE = 'https://api.twitter.com'.freeze

  def x_consumer
    ::OAuth::Consumer.new(
      consumer_key,
      consumer_secret,
      site: X_SITE,
      request_token_path: '/oauth/request_token',
      access_token_path: '/oauth/access_token',
      authorize_path: '/oauth/authorize'
    )
  end

  def x_access_token(channel)
    ::OAuth::AccessToken.new(x_consumer, channel.access_token, channel.access_token_secret)
  end

  private

  def consumer_key
    GlobalConfigService.load('X_CONSUMER_KEY', nil)
  end

  def consumer_secret
    GlobalConfigService.load('X_CONSUMER_SECRET', nil)
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
