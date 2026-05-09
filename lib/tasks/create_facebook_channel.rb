# Quick script to create a Facebook channel programmatically
# Usage: bundle exec rails runner 'eval(File.read("lib/tasks/create_facebook_channel.rb"))'
# Or just paste this into `bundle exec rails console`

# Change these values to your Facebook credentials
PAGE_ID = 'YOUR_PAGE_ID'
PAGE_ACCESS_TOKEN = 'YOUR_PAGE_ACCESS_TOKEN'
USER_ACCESS_TOKEN = 'YOUR_USER_ACCESS_TOKEN' # Can be empty string if not available
INBOX_NAME = 'My Facebook Page'
ACCOUNT_ID = 1 # Change to the account you want to add this to

# Find the account
account = Account.find(ACCOUNT_ID)

# Create the Facebook channel and inbox
ActiveRecord::Base.transaction do
  facebook_channel = account.facebook_pages.create!(
    page_id: PAGE_ID,
    user_access_token: USER_ACCESS_TOKEN,
    page_access_token: PAGE_ACCESS_TOKEN
  )
  puts "✓ Created Facebook channel with ID: #{facebook_channel.id}"

  facebook_inbox = account.inboxes.create!(
    name: INBOX_NAME,
    channel: facebook_channel,
    queue_kind: 'dm'
  )
  puts "✓ Created inbox '#{INBOX_NAME}' with ID: #{facebook_inbox.id}"

  # Try to fetch Instagram account if available
  begin
    fb_object = Koala::Facebook::API.new(PAGE_ACCESS_TOKEN)
    response = fb_object.get_connections('me', '', { fields: 'instagram_business_account' })
    if response['instagram_business_account'].present?
      instagram_id = response['instagram_business_account']['id']
      facebook_channel.update(instagram_id: instagram_id)
      puts "✓ Added Instagram account (ID: #{instagram_id})"
    end
  rescue StandardError => e
    puts "⚠ Could not fetch Instagram details: #{e.message}"
  end

  # Set avatar in background
  Avatar::AvatarFromUrlJob.perform_later(facebook_inbox, "https://graph.facebook.com/#{PAGE_ID}/picture?type=large")
  puts '✓ Avatar job queued'
end

puts "\n✅ Facebook channel setup complete!"
puts "Channel: #{facebook_channel.name}"
puts "Inbox: #{facebook_inbox.name}"
