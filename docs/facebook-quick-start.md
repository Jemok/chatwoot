# Quick Start: Facebook Messenger Channel Setup (Admin Form)

## 🚀 60-Second Setup

### Step 1: Get Your Credentials (5 min)

**From Facebook Developers Console:**

1. Your app exists or [create one here](https://developers.facebook.com/)
2. Go to **Settings → Basic** and copy:
   - `App ID`: `YOUR_APP_ID`
   - `App Secret`: `YOUR_APP_SECRET`

3. Go to **Messenger** → **Settings** → **Access Tokens**
4. Select your page dropdown
5. Click **Generate Token**
6. Copy: `EAA...` (Your Page Access Token)

7. Also copy your Facebook **Page ID** from your page settings

### Step 2: Access Admin Form (1 min)

1. Log into Chatwoot as Super Admin
2. Navigate to: **Super Admin** → **Accounts** → Click your account
3. Scroll to bottom: **Add Facebook Messenger Channel** section

### Step 3: Fill & Submit (1 min)

**Copy-paste these fields:**

| Field | Value | Required? |
|-------|-------|-----------|
| Page ID | `123456789012345` | ✅ Yes |
| Page Access Token | `EAAB...xyz` | ✅ Yes |
| User Access Token | `EAA...` | ❌ No |
| Inbox Name | `My Facebook Page` | ✅ Yes |

Click: **Create Facebook Channel**

### ✅ Done!

Your channel is now ready. Facebook messages will appear in Chatwoot.

---

## 📋 What Just Happened?

✓ Channel created
✓ DM Inbox created
✓ Webhook configured
✓ Avatar downloaded
✓ Instagram linked (if available)

---

## 🧪 Test It

1. Send a message to your Facebook page
2. Check your Chatwoot inbox
3. Message should appear!

---

## 🆘 Not Working?

### Messages not appearing?

Check webhook subscription:
```bash
cd /path/to/chatwoot
bundle exec rails console
channel = Channel::FacebookPage.last
channel.subscribe  # Should return true
```

### Still stuck?

See detailed guide: `docs/facebook-setup-admin.md`

---

## 💻 Alternative: Rails Console Setup

If you prefer scripts:

```bash
bundle exec rails console

PAGE_ID = "123456789012345"
PAGE_ACCESS_TOKEN = "EAAB...xyz"
INBOX_NAME = "My Facebook Page"
ACCOUNT_ID = 1

account = Account.find(ACCOUNT_ID)
channel = account.facebook_pages.create!(
  page_id: PAGE_ID,
  page_access_token: PAGE_ACCESS_TOKEN,
  user_access_token: ""
)
account.inboxes.create!(
  name: INBOX_NAME,
  channel: channel,
  queue_kind: 'dm'
)

puts "✅ Created!"
```

---

**That's it!** 🎉

Your Facebook channel is now live.

See `docs/facebook-setup-admin.md` for full docs.

