# Facebook Messenger Channel Admin Form - Implementation Summary

## What's been built

I've created a **simple admin form** to add Facebook Messenger channels directly in Chatwoot's Super Admin dashboard, completely bypassing the OAuth login flow. This gives you three ways to set up channels:

### 1. **Web Form (Super Admin Dashboard)** ✨ New!

- **Location**: Super Admin → Accounts → [Select Account] → Scroll to bottom
- **Form fields**:
  - Page ID (required)
  - Page Access Token (required)
  - User Access Token (optional)
  - Inbox Name (required)
- **One-click Setup**: Just paste credentials and click "Create Facebook Channel"

### 2. **Rails Console** (Programmatic)

```bash
bundle exec rails console
# Paste the script from lib/tasks/create_facebook_channel.rb with your credentials
```

### 3. **API Endpoint** (Already existed)

```bash
POST /api/v1/accounts/1/callbacks/register_facebook_page
```

---

## Files Created/Modified

### New Files
```
app/views/super_admin/accounts/_facebook_channel.html.erb
  └─ Form partial with input fields for credentials

lib/tasks/create_facebook_channel.rb
  └─ Example script for console-based setup

docs/facebook-setup-admin.md
  └─ Comprehensive setup guide (includes credential retrieval steps)
```

### Modified Files
```
config/routes.rb
  └─ Added: post :create_facebook_channel, on: :member (line 715)

app/controllers/super_admin/accounts_controller.rb
  └─ Added: create_facebook_channel method
  └─ Added: set_instagram_id (private)
  └─ Added: set_avatar (private)

app/views/super_admin/accounts/show.html.erb
  └─ Added: partial render for facebook_channel form (line 100)
```

---

## How It Works Step-by-Step

### Process Flow

1. **User submits form** with credentials
   ↓
2. **Controller validates** and creates `Channel::FacebookPage` record
   ↓
3. **Automatically creates** a DM inbox linked to the channel
   ↓
4. **Fetches Instagram ID** (if linked to this page)
   ↓
5. **Subscribes webhook** to Facebook's Messenger API
   ↓
6. **Queues avatar download** from Facebook Graph API
   ↓
7. **Returns success message** and channel is ready to use

### What Happens Behind the Scenes

When you submit the form, the controller:

```ruby
# 1. Creates the channel with access tokens
facebook_channel = account.facebook_pages.create!(
  page_id: page_id,
  user_access_token: user_access_token,
  page_access_token: page_access_token
)

# 2. Creates the DM inbox
facebook_inbox = account.inboxes.create!(
  name: inbox_name,
  channel: facebook_channel,
  queue_kind: 'dm'  # Direct Messages
)

# 3. Tries to link Instagram account (if available)
# 4. Automatically subscribes to Facebook webhooks (line 29 in FacebookPage model)
# 5. Downloads and sets the inbox avatar
```

---

## Getting Your Credentials

👉 **See `docs/facebook-setup-admin.md` for detailed step-by-step instructions**

Quick summary:
1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Select your app → Settings → Basic → Copy **App ID, App Secret**
3. Go to your Facebook Page → Settings → Page Info → Copy **Page ID**
4. Back in Developers → App → Messenger → Access Tokens → Generate **Page Access Token**
5. (Optional) Generate **User Access Token** for better integration

---

## Testing the Setup

### Test via Super Admin Dashboard

1. Log in as super admin
2. Navigate to: **Super Admin** → **Accounts**
3. Click on an account
4. Scroll to **Add Facebook Messenger Channel** section
5. Fill in credentials and submit

### Test via Rails Console

```bash
bundle exec rails console

# Edit these values:
PAGE_ID = "123456789"
PAGE_ACCESS_TOKEN = "EAA..."
ACCOUNT_ID = 1

# Run the setup
account = Account.find(ACCOUNT_ID)
facebook_channel = account.facebook_pages.create!(
  page_id: PAGE_ID,
  page_access_token: PAGE_ACCESS_TOKEN,
  user_access_token: ""
)
facebook_inbox = account.inboxes.create!(
  name: "My Facebook Page",
  channel: facebook_channel,
  queue_kind: 'dm'
)

# Verify it worked
puts facebook_channel.inbox.name  # Should output your inbox name
puts facebook_channel.page_id      # Should output your page ID
```

### Verify Webhook

Once created, Facebook will send messages to: `https://YOUR_DOMAIN/bot`

To test:
```bash
# Send a test message via Facebook
# Check it appears in your Chatwoot inbox

# Or check webhook subscription status:
bundle exec rails console
channel = Channel::FacebookPage.find_by(page_id: "YOUR_PAGE_ID")
channel.subscribe  # Returns true if subscribed successfully
```

---

## Key Features

✅ **No OAuth Required** - Direct credential input
✅ **One-Step Setup** - Creates channel, inbox, and webhook subscription
✅ **Instagram Support** - Auto-detects and links Instagram accounts
✅ **Error Handling** - Graceful fallbacks if Instagram not linked
✅ **Avatar Support** - Automatically downloads page profile picture
✅ **Transaction-Safe** - Entire operation wrapped in transaction (rollback on error)
✅ **Secure** - Tokens encrypted at rest if `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` set
✅ **Logging** - Comprehensive error logging for debugging

---

## Security Considerations

⚠️ **Important**

1. **Never commit credentials to Git** - Use environment variables
2. **Access tokens are sensitive** - Treat like passwords
3. **Token rotation** - Rotate tokens regularly
4. **Encryption** - Enable encryption keys in production:
   ```bash
   rails db:encryption:init
   # Add keys to .env:
   ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
   ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...
   ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
   ```

---

## Troubleshooting

### Form doesn't appear
- Confirm you're logged in as a Super Admin
- Check browser network tab for 404 errors

### "Invalid access token" error
- Verify the Page Access Token is correct
- Ensure it hasn't expired
- Check Facebook hasn't revoked app permissions

### Webhook not receiving messages
- Verify webhook URL in Facebook Developers Console:
  - Go to Messenger → Settings → Webhooks
  - URL should be: `https://YOUR_DOMAIN/bot`
  - Verify "Completed" status
- Check Chatwoot logs: `tail -f log/development.log | grep facebook`
- Manually trigger subscribe:
  ```ruby
  Channel::FacebookPage.find(channel_id).subscribe
  ```

### Instagram not linking
- Not all pages have linked Instagram accounts - this is optional
- Won't affect channel creation if not available

---

## Next Steps

After creating the channel:

1. **Add Agents** to the Facebook inbox so they can reply
2. **Send a test message** to your page to verify it works
3. **Configure Teams/Labels** for organizing conversations
4. **Set up Automation Rules** if desired
5. **Review Logs** to ensure webhooks are being received

---

## Code References

- **Channel Model**: `app/models/channel/facebook_page.rb` (auto-subscribes on create)
- **Controller Action**: `app/controllers/super_admin/accounts_controller.rb`
- **Form View**: `app/views/super_admin/accounts/_facebook_channel.html.erb`
- **Webhook Handler**: `app/controllers/facebook/messenger/server` (at `/bot`)
- **Message Processing**: `lib/integrations/facebook/message_creator.rb`

---

## Support

For detailed setup instructions, see: **`docs/facebook-setup-admin.md`**

This document contains:
- Step-by-step credential retrieval
- Webhook verification
- Advanced troubleshooting
- API reference

---

**Status**: ✅ Ready to use
**Created**: 2026-05-09
**Test Priority**: High - verify webhook events flow correctly

