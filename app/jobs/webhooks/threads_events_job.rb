class Webhooks::ThreadsEventsJob < ApplicationJob
  queue_as :default

  # https://developers.facebook.com/docs/threads/webhooks
  # Threads has no DM API — supported webhook fields are:
  # - replies (replies to our own threads)
  # - mentions (@-mentions in others' threads)
  # - quotes  (quotes of our own threads)
  def perform(entries)
    Array(entries).each do |entry|
      process_single_entry(entry.with_indifferent_access)
    end
  end

  private

  def process_single_entry(entry)
    threads_user_id = entry[:id]
    Array(entry[:changes]).each do |change|
      case change[:field].to_s
      when 'replies'
        ::Webhooks::ThreadsReplyEventsJob.perform_later(threads_user_id, change[:value].to_json)
      when 'mentions', 'quotes'
        ::Webhooks::ThreadsMentionEventsJob.perform_later(threads_user_id, change[:field].to_s, change[:value].to_json)
      end
    end
  end
end
