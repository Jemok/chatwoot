# frozen_string_literal: true

# Threads a Play Store review (and any developer reply) into Chatwoot.
# Conversation identifier = reviewId. The user comment is incoming; the
# existing developer reply (if any) is recorded as outgoing so the timeline matches the Play Console.
class Integrations::PlayStore::ReviewMessageCreator
  def initialize(channel, inbox, review)
    @channel = channel
    @inbox = inbox
    @review = review
  end

  def perform
    return if review_id.blank?
    return if user_comment.blank?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_user_message
      create_developer_message if developer_comment.present?
    end
  end

  private

  def review_id
    @review['reviewId']
  end

  def author_name
    @review['authorName'].presence || 'Play Store User'
  end

  def comments
    Array(@review['comments'])
  end

  def user_comment
    @user_comment ||= comments.find { |c| c['userComment'].present? }
  end

  def developer_comment
    @developer_comment ||= comments.find { |c| c['developerComment'].present? }
  end

  def user_text
    user_comment.dig('userComment', 'text').to_s
  end

  def developer_text
    developer_comment.dig('developerComment', 'text').to_s
  end

  # Composite source_id includes lastModified seconds so an edited review
  # does not duplicate but also does not silently overwrite — newer edits
  # appear as new messages. Use only the unix seconds, not nanos.
  def user_source_id
    "#{review_id}:user:#{user_comment.dig('userComment', 'lastModified', 'seconds')}"
  end

  def developer_source_id
    "#{review_id}:dev:#{developer_comment.dig('developerComment', 'lastModified', 'seconds')}"
  end

  def build_contact_inbox
    source_id = "ps-#{Digest::SHA256.hexdigest(review_id)[0..15]}"
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: source_id,
      inbox: @inbox,
      contact_attributes: { name: author_name }
    ).perform
  end

  def find_or_create_conversation
    @conversation = Conversation.where(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      identifier: review_id
    ).order(created_at: :desc).first

    return if @conversation

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: review_id,
      additional_attributes: {
        type: 'play_store_review',
        review_id: review_id,
        star_rating: user_comment.dig('userComment', 'starRating'),
        app_version_name: user_comment.dig('userComment', 'appVersionName'),
        device: user_comment.dig('userComment', 'device'),
        package_name: @channel.package_name
      }
    )
  end

  def create_user_message
    return if Message.exists?(source_id: user_source_id, inbox_id: @inbox.id)

    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: user_text,
      source_id: user_source_id,
      sender: @contact_inbox.contact,
      content_attributes: { type: 'play_store_review', review_id: review_id }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def create_developer_message
    return if Message.exists?(source_id: developer_source_id, inbox_id: @inbox.id)

    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: developer_text,
      source_id: developer_source_id,
      content_attributes: { type: 'play_store_developer_reply', review_id: review_id }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
