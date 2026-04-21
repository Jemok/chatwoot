# frozen_string_literal: true

# Processes incoming X tweet replies to our authored tweets.
# Conversation identifier = root conversation_id (X thread root tweet id).
class Integrations::X::ReplyMessageCreator
  def initialize(channel, inbox, tweet, users)
    @channel = channel
    @inbox = inbox
    @tweet = tweet
    @users = users || {}
  end

  def perform
    return if tweet_id.blank?
    return if author_id.blank?
    return if own_reply?
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
    @tweet['user']&.dig('id_str') || @tweet['user_id_str'] || @users.keys.first
  end

  def own_reply?
    author_id.to_s == @channel.x_user_id.to_s
  end

  def duplicate_message?
    Message.exists?(source_id: tweet_id, inbox_id: @inbox.id)
  end

  def author_user
    @users[author_id] || @tweet['user'] || {}
  end

  def sender_name
    author_user['name'] || author_user['screen_name'] || author_user['username'] || 'X User'
  end

  def root_id
    @tweet['conversation_id_str'] || @tweet['in_reply_to_status_id_str'] || tweet_id
  end

  def parent_id
    @tweet['in_reply_to_status_id_str']
  end

  def message_text
    @tweet['text'] || @tweet['full_text'] || @tweet.dig('extended_tweet', 'full_text')
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
      identifier: root_id
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: root_id,
      additional_attributes: {
        type: 'tweet_reply',
        post_id: root_id
      }
    )
  end

  def create_message
    attrs = { type: 'tweet_reply', post_id: root_id, parent_id: parent_id }
    if parent_id.present? && parent_id != root_id
      parent_message = @inbox.messages.find_by(source_id: parent_id)
      attrs[:in_reply_to] = parent_message.id if parent_message
      attrs[:in_reply_to_external_id] = parent_id
    end

    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: message_text,
      source_id: tweet_id,
      sender: @contact_inbox.contact,
      content_attributes: attrs
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
