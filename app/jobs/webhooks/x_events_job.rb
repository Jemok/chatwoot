class Webhooks::XEventsJob < ApplicationJob
  queue_as :default

  # X Account Activity payload shape:
  # {
  #   "for_user_id": "<our_x_user_id>",
  #   "tweet_create_events": [ {tweet}, ... ],          # mentions / replies
  #   "direct_message_events": [ {dm}, ... ],
  #   "users": { "<id>": { ... } }                      # actor lookup
  # }
  def perform(payload)
    payload = payload.with_indifferent_access
    x_user_id = payload[:for_user_id].to_s
    return if x_user_id.blank?

    users = payload[:users] || {}

    Array(payload[:tweet_create_events]).each do |tweet|
      ::Webhooks::XReplyEventsJob.perform_later(x_user_id, tweet.to_json, users.to_json)
    end

    Array(payload[:direct_message_events]).each do |dm|
      ::Webhooks::XDmEventsJob.perform_later(x_user_id, dm.to_json, users.to_json)
    end
  end
end
