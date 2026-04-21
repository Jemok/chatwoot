# frozen_string_literal: true

# Polls YouTube Data API v3 for new comments across all videos on the
# authenticated channel. One conversation per video (identifier=videoId);
# one message per comment (source_id=commentId). Top-level comments and
# their replies thread via in_reply_to_external_id.
#
# Quota: 1 unit per call. 5-min polling × 1 channel ≈ 290/day (10 000/day default).
class Integrations::Youtube::CommentsPoller
  PAGE_SIZE = 100

  def initialize(channel)
    @channel = channel
    @inbox = channel.inbox
  end

  def perform
    return unless @inbox

    fetch_comment_threads.each do |thread|
      top_level = thread.dig('snippet', 'topLevelComment')
      process_comment(top_level, thread.dig('snippet', 'videoId'), nil) if top_level

      Array(thread.dig('replies', 'comments')).each do |reply|
        process_comment(reply, thread.dig('snippet', 'videoId'), top_level&.dig('id'))
      end
    end

    @channel.update_columns(last_polled_at: Time.current)
  end

  private

  def process_comment(comment, video_id, parent_id)
    return if comment.blank? || video_id.blank?

    ::Integrations::Youtube::CommentMessageCreator.new(@channel, @inbox, comment, video_id, parent_id).perform
  end

  def fetch_comment_threads
    response = HTTParty.get(
      'https://www.googleapis.com/youtube/v3/commentThreads',
      query: {
        part: 'snippet,replies',
        allThreadsRelatedToChannelId: @channel.youtube_channel_id,
        maxResults: PAGE_SIZE,
        order: 'time'
      },
      headers: { 'Authorization' => "Bearer #{@channel.access_token}", 'Accept' => 'application/json' }
    )

    return Array(JSON.parse(response.body)['items']) if response.success?

    Rails.logger.warn("[Youtube::CommentsPoller] channel=#{@channel.id} HTTP #{response.code}: #{response.body}")
    @channel.authorization_error! if response.code.to_i == 401
    []
  rescue StandardError => e
    Rails.logger.warn("[Youtube::CommentsPoller] channel=#{@channel.id} #{e.class}: #{e.message}")
    []
  end
end
