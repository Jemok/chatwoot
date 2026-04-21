# frozen_string_literal: true

# Threads an App Store customer review (and optional developer response) into Chatwoot.
class Integrations::AppStore::ReviewMessageCreator
  def initialize(channel, inbox, review, response_resource)
    @channel = channel
    @inbox = inbox
    @review = review
    @response = response_resource
  end

  def perform
    return if review_id.blank?
    return if review_text.blank?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_user_message
      create_developer_message if @response
    end
  end

  private

  def attrs
    @attrs ||= @review['attributes'] || {}
  end

  def review_id
    @review['id']
  end

  def review_text
    [attrs['title'], attrs['body']].compact.reject(&:empty?).join("\n\n")
  end

  def author_name
    attrs['reviewerNickname'].presence || 'App Store User'
  end

  def user_source_id
    "as-review-#{review_id}"
  end

  def developer_source_id
    "as-response-#{@response['id']}"
  end

  def build_contact_inbox
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: "as-#{Digest::SHA256.hexdigest(review_id)[0..15]}",
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
        type: 'app_store_review',
        review_id: review_id,
        rating: attrs['rating'],
        territory: attrs['territory'],
        app_version: attrs['appVersionString'],
        app_id: @channel.app_id
      }
    )
  end

  def create_user_message
    return if Message.exists?(source_id: user_source_id, inbox_id: @inbox.id)

    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: review_text,
      source_id: user_source_id,
      sender: @contact_inbox.contact,
      content_attributes: { type: 'app_store_review', review_id: review_id }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def create_developer_message
    return if Message.exists?(source_id: developer_source_id, inbox_id: @inbox.id)

    body = @response.dig('attributes', 'responseBody').to_s
    return if body.blank?

    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: body,
      source_id: developer_source_id,
      content_attributes: { type: 'app_store_developer_response', review_id: review_id }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
