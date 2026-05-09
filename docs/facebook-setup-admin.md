# Facebook Messenger Channel Setup Guide

## Overview

This guide explains how to create a Facebook Messenger channel in Chatwoot **without the OAuth login flow**, using either:

1. **Admin Super Dashboard** (Web UI) - Simple form-based setup
2. **Rails Console** - Programmatic setup

---

## Prerequisites

You need a Facebook app with the required permissions. If you don't have one yet, create one at [Facebook Developers](https://developers.facebook.com/).

---

## Getting Your Facebook Credentials

### Step 1: Get Your Facebook App ID & Secret

1. Go to [Facebook Developers Console](https://developers.facebook.com/)
2. Select your app (or create one)
3. Navigate to **Settings** → **Basic**
4. Copy your **App ID** and **App Secret**

### Step 2: Get Your Page ID

1. Go to your Facebook page
2. Navigate to **Settings** → **Page Info**
3. Copy the **Page ID**
4. Alternatively, look for it in the URL or use the Facebook Graph API

### Step 3: Generate Your Page Access Token

1. In the Facebook Developers Console, go to your app
2. Navigate to **Messenger** → **Settings**
3. Under **Access Tokens**, select your page from the dropdown
4. Click **Generate Token**
5. Copy the **Page Access Token**
6. **Important:** Keep this token secure—anyone with this can send messages on behalf of your page

### Step 4: Get Your User Access Token (Optional)

This is optional but recommended for better integration:

1. In the Facebook Login section, authenticate yourself
2. Copy your **User Access Token**
3. This helps with fetching page details and managing subscriptions

---

## Method 1: Super Admin Dashboard (Web UI)

### Access the Form

1. Log in to Chatwoot as a Super Admin
2. Navigate to **Super Admin** → **Accounts**
3. Click on the account where you want to add the Facebook channel
4. Scroll to the bottom of the page
5. Find the **Add Facebook Messenger Channel** section

### Fill in the Form

**Required Fields:**
- **Page ID**: Your Facebook page ID (e.g., `123456789012345`)
- **Page Access Token**: Your page access token (e.g., `EAA...xyz`)
- **Inbox Name**: What you want to call this inbox (e.g., `My Facebook Page`)

**Optional Field:**
- **User Access Token**: Your user access token (recommended)

### Submit

Click **Create Facebook Channel** and the system will:

1. ✓ Create a `Channel::FacebookPage` record
2. ✓ Create a DM inbox for Messenger conversations
3. ✓ Automatically subscribe to Facebook webhook events
4. ✓ Fetch Instagram account details if available
5. ✓ Queue the avatar download from Facebook

---

## Method 2: Rails Console (Programmatic)

### Quick Setup

```bash
cd /path/to/chatwoot
bundle exec rails console
```

Then copy and paste this script, updating the credentials:

```ruby
# Configuration
PAGE_ID = "123456789012345"
PAGE_ACCESS_TOKEN = "EAA...xyz"
USER_ACCESS_TOKEN = "EAAB...abc" # or empty string: ""
INBOX_NAME = "My Facebook Page"
ACCOUNT_ID = 1  # Change to your account ID

# Create the channel
account = Account.find(ACCOUNT_ID)

ActiveRecord::Base.transaction do
  facebook_channel = account.facebook_pages.create!(
    page_id: PAGE_ID,
    user_access_token: USER_ACCESS_TOKEN,
    page_access_token: PAGE_ACCESS_TOKEN
  )
  puts "✓ Created Facebook channel"

  facebook_inbox = account.inboxes.create!(
    name: INBOX_NAME,
    channel: facebook_channel,
    queue_kind: 'dm'
  )
  puts "✓ Created inbox: #{INBOX_NAME}"

  Avatar::AvatarFromUrlJob.perform_later(facebook_inbox, "https://graph.facebook.com/#{PAGE_ID}/picture?type=large")
  puts "✓ Avatar queued"
end

puts "✅ Setup complete!"
```

### Using a Script File

Alternatively, edit `/lib/tasks/create_facebook_channel.rb`, update the credentials, then run:

```bash
bundle exec rails runner 'eval(File.read("lib/tasks/create_facebook_channel.rb"))'
```

---

## Verify Your Setup

### Check if Channel Created Successfully

```ruby
# In Rails console
channel = Channel::FacebookPage.find_by(page_id: "YOUR_PAGE_ID")
channel.inbox  # Should return your inbox

# Check webhook subscription
channel.subscribe  # This should return successfully

# View your new inbox
inbox = Inbox.find_by(channel_id: channel.id)
inbox.name  # Should show your inbox name
```

### Check Webhook Events

Once set up, Facebook will send webhook events to:

```
https://YOUR_CHATWOOT_DOMAIN/bot
```

This is handled by the `Facebook::Messenger::Server` in `config/routes.rb`.

---

## Troubleshooting

### "Invalid access token"

- Verify the **Page Access Token** is correct and hasn't expired
- Try generating a new token from Facebook Developers Console
- Ensure the token has `pages_messaging` permission

### "Page not found"

- Check that the **Page ID** is correct
- Verify the token has access to this specific page

### "Instagram account not found"

- Not all pages have Instagram accounts linked
- This is optional and won't break the setup if unavailable

### Webhook not receiving messages

1. Verify your webhook URL in Facebook Developers Console:
   - Go to **Messenger** → **Settings** → **Webhooks**
   - Confirm the URL is set to `https://YOUR_DOMAIN/bot`
   - Verify the subscribe button shows "Completed"

2. Check that the subscription happened:
   ```ruby
   channel = Channel::FacebookPage.find_by(page_id: "YOUR_PAGE_ID")
   channel.subscribe  # Should return true or truthy
   ```

3. Look in Chatwoot logs for any errors:
   ```bash
   tail -f log/development.log | grep -i facebook
   ```

---

## Architecture Notes

### What Happens When You Create a Channel

The `create_facebook_channel` controller action (in `SuperAdmin::AccountsController`):

1. **Creates the Channel**: Stores `page_id`, `page_access_token`, and `user_access_token` in the `channel_facebook_pages` table
2. **Creates the Inbox**: Links to the channel with `queue_kind: 'dm'` (Direct Messages)
3. **Fetches Instagram ID**: If the page has an Instagram account, it's linked automatically
4. **Subscribes to Webhook**: Calls Facebook Graph API to register for message events
5. **Sets Avatar**: Queues a bg job to download the page's profile picture

### Where Messages Are Processed

When Facebook sends a webhook event to `/bot`:

- `Facebook::Messenger::Server` (webhook handler) receives it
- `lib/integrations/facebook/message_creator.rb` processes the message
- Messages land in your inbox and are ready for agents to respond

### Encryption

Access tokens are **encrypted at rest** if `Chatwoot.encryption_configured?` is true:
- Add `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` to your `.env`
- Run `rails db:encryption:init` if needed

---

## Security Notes

⚠️ **IMPORTANT**

- **Never commit access tokens to Git**
- Store them securely in environment variables or secrets management
- Rotate tokens regularly
- Use the `User Access Token` only if necessary for your app's features
- The `Page Access Token` is used to send messages—treat it like a password

---

## Next Steps

After creating the channel:

1. **Create an Inbox Member**: Add agents to the Facebook inbox so they can reply to messages
2. **Test**: Send a message to your page and check if it appears in Chatwoot
3. **Set Up Teams/Labels**: Organize conversations with teams and labels
4. **Automation**: Set up automation rules if desired

---

## API Reference

### Manual Channel Creation via API

You can also create a channel via the internal API endpoint (requires account authorization):

```bash
curl -X POST "http://localhost:3000/api/v1/accounts/1/callbacks/register_facebook_page" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "page_id": "123456789012345",
    "page_access_token": "EAAB...",
    "user_access_token": "EAA...",
    "inbox_name": "My Page"
  }'
```

---

## Support

If you encounter issues:

1. Check the [Chatwoot Docs](https://www.chatwoot.com/docs/facebook-setup)
2. Review the logs: `tail -f log/development.log`
3. Verify webhook events are reaching your server
4. Ensure the page access token has the correct permissions

---

Created: 2026-05-09
Updated: 2026-05-09

