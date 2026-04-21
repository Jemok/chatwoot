namespace :x do
  # ---- Webhook management endpoints use OAuth 2.0 App-Only (Bearer Token) ----

  desc 'Register the X v2 webhook with FRONTEND_URL/webhooks/x. Stores returned id in X_WEBHOOK_ID.'
  task register_webhook: :environment do
    url = "#{ENV.fetch('FRONTEND_URL')}/webhooks/x"
    response = bearer_request(:post, '/2/webhooks', JSON.generate(url: url), 'Content-Type' => 'application/json')
    puts "POST /2/webhooks status=#{response.code}"
    puts response.body

    parsed = JSON.parse(response.body) rescue {}
    webhook_id = parsed.dig('data', 'id') || parsed['id']
    if webhook_id
      InstallationConfig.find_or_initialize_by(name: 'X_WEBHOOK_ID').update!(value: webhook_id)
      GlobalConfig.clear_cache
      puts "Saved X_WEBHOOK_ID=#{webhook_id}"
    end
  end

  desc 'List registered X v2 webhooks for this app.'
  task list_webhooks: :environment do
    response = bearer_request(:get, '/2/webhooks')
    puts "GET /2/webhooks status=#{response.code}"
    puts response.body
  end

  desc 'Trigger CRC re-validation for the saved webhook.'
  task validate_webhook: :environment do
    webhook_id = GlobalConfigService.load('X_WEBHOOK_ID', nil) or abort('X_WEBHOOK_ID not set.')
    response = bearer_request(:put, "/2/webhooks/#{webhook_id}")
    puts "PUT /2/webhooks/#{webhook_id} status=#{response.code}"
    puts response.body
  end

  desc 'Delete the saved X webhook from X (does not clear X_WEBHOOK_ID).'
  task delete_webhook: :environment do
    webhook_id = GlobalConfigService.load('X_WEBHOOK_ID', nil) or abort('X_WEBHOOK_ID not set.')
    response = bearer_request(:delete, "/2/webhooks/#{webhook_id}")
    puts "DELETE /2/webhooks/#{webhook_id} status=#{response.code}"
    puts response.body
  end

  # ---- Subscriptions use OAuth 1.0a User context (per-user) ----

  desc 'Subscribe (or re-subscribe) every Channel::X to the saved webhook.'
  task subscribe_all: :environment do
    Channel::X.find_each do |c|
      puts "channel=#{c.id} username=#{c.username}"
      res = c.subscribe
      puts "  -> #{res.respond_to?(:code) ? res.code : res.inspect}"
    end
  end

  # ---- helpers ----

  def bearer_request(method, path, body = nil, headers = {})
    require 'net/http'
    bearer = GlobalConfigService.load('X_BEARER_TOKEN', nil) or abort('X_BEARER_TOKEN not set in Super Admin → Settings.')

    uri = URI("https://api.twitter.com#{path}")
    klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put, delete: Net::HTTP::Delete }.fetch(method)
    req = klass.new(uri)
    req['Authorization'] = "Bearer #{bearer}"
    headers.each { |k, v| req[k] = v }
    req.body = body if body

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  end
end
