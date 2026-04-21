# frozen_string_literal: true

# Polls the LinkedIn REST API for new comments on our authored posts and
# routes them through CommentMessageCreator (dedup via Message#source_id).
#
# Requires `r_organization_social` (org mode) or `w_member_social`+
# `r_member_social` (member mode). When neither scope is granted the API
# returns 403 → we log and no-op.
class Integrations::Linkedin::CommentsPoller
  POSTS_LIMIT = 20
  COMMENTS_LIMIT = 50

  def initialize(channel)
    @channel = channel
  end

  def perform
    inbox = @channel.inbox
    return unless inbox

    fetch_recent_posts.each do |post_urn|
      fetch_comments(post_urn).each do |comment|
        next if comment['id'].blank?
        next if Message.exists?(source_id: comment['id'].to_s, inbox_id: inbox.id)

        comment['actor_name'] ||= resolve_actor_name(comment['actor'])
        ::Integrations::Linkedin::CommentMessageCreator.new(@channel, inbox, comment).perform
      end
    end
  end

  private

  def author_urn
    @author_urn ||= @channel.organization_urn.presence || @channel.linkedin_user_urn
  end

  def fetch_recent_posts
    body = api_get('/rest/posts', { q: 'author', author: author_urn, count: POSTS_LIMIT, sortBy: 'LAST_MODIFIED' })
    Array(body['elements']).map { |p| p['id'] || p['urn'] }.compact
  rescue StandardError => e
    Rails.logger.warn("[Linkedin::CommentsPoller] channel=#{@channel.id} posts list error: #{e.message}")
    []
  end

  def fetch_comments(post_urn)
    body = api_get("/rest/socialActions/#{CGI.escape(post_urn)}/comments", { count: COMMENTS_LIMIT })
    Array(body['elements'])
  rescue StandardError => e
    Rails.logger.warn("[Linkedin::CommentsPoller] channel=#{@channel.id} post=#{post_urn} comments error: #{e.message}")
    []
  end

  # Lazy actor resolution. LinkedIn `/rest/people/{urn}` returns localized
  # firstName/lastName when the requesting token has the relevant scope.
  # Failure → fall back to URN tail in the creator.
  def resolve_actor_name(urn)
    return if urn.blank?

    body = api_get("/rest/people/#{CGI.escape(urn)}", {})
    first = body.dig('firstName', 'localized')&.values&.first
    last = body.dig('lastName', 'localized')&.values&.first
    [first, last].compact.join(' ').presence
  rescue StandardError
    nil
  end

  def api_get(path, query)
    response = HTTParty.get(
      "https://api.linkedin.com#{path}",
      query: query,
      headers: {
        'Authorization' => "Bearer #{@channel.access_token}",
        'Accept' => 'application/json',
        'LinkedIn-Version' => GlobalConfigService.load('LINKEDIN_API_VERSION', '202604'),
        'X-Restli-Protocol-Version' => '2.0.0'
      }
    )
    raise "HTTP #{response.code}: #{response.body}" unless response.success?

    JSON.parse(response.body)
  end
end
