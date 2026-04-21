# frozen_string_literal: true

# Processes incoming X mentions and quotes (tweet_create_events that are
# not replies addressed to us). Routed to the Mentions sub-inbox.
class Integrations::X::MentionMessageCreator
  def initialize(channel, inbox, tweet, users)
    @channel = channel
    @inbox = inbox
    @tweet = tweet
    @users = users || {}
  end

  def perform
    return if tweet_id.blank?
    return if author_id.blank?
    return if author_id.to_s == @channel.x_user_id.to_s
    return if duplicate_message?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def tweet_id
    @tweet['id_str'] || @tweet['id'].to_s
  end

  def author_id
    @tweet['user']&.dig('id_str') || @tweet['user_id_str']
  end

  def author_user
    @users[author_id] || @tweet['user'] || {}
  end

  def sender_name
    author_user['name'] || author_user['screen_name'] || author_user['username'] || 'X User'
  end

  def quote?
    @tweet['is_quote_status'] == true || @tweet['quoted_status_id_str'].present?
  end

  def message_text
    @tweet['text'] || @tweet['full_text'] || @tweet.dig('extended_tweet', 'full_text')
  end

  def duplicate_message?
    Message.exists?(source_id: tweet_id, inbox_id: @inbox.id)
  end

  def build_contact_inbox
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: author_id,
      inbox: @inbox,
      contact_attributes: { name: sender_name }
    ).perform
  end

  def find_or_create_conversation
    @conversation = Conversation.where(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      identifier: tweet_id
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: tweet_id,
      additional_attributes: {
        type: 'tweet_mention',
        post_id: tweet_id,
        is_quote: quote?
      }
    )
  end

  def create_message
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: message_text,
      source_id: tweet_id,
      sender: @contact_inbox.contact,
      content_attributes: { type: quote? ? 'tweet_quote' : 'tweet_mention', post_id: tweet_id }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
