# Phase 5 — Threads Channel Deployment Runbook

This is the one-time infra/Meta configuration required to light up the Threads
integration built in Phases 1–4. Chatwoot code is already ready; this runbook
plugs it into Meta.

> **Prerequisites**
> - Chatwoot instance deployed with the Threads migration applied
>   (`bundle exec rails db:migrate`)
> - Public HTTPS URL for your Chatwoot (call it `https://<your-host>`)
> - Admin access to a Meta App at https://developers.facebook.com/apps

---

## 1. Meta App — add the Threads product

The **same Meta app** you use for Facebook/Instagram can host Threads. If you
don't have one yet, create a new app: **Other → Business**.

1. Open https://developers.facebook.com/apps → select your app.
2. Left sidebar → **Add Product** → find **Threads** → **Set up**.
3. Under **Threads → API setup with Threads login**, complete the checklist:
   - Create a **Threads Login app** (Meta wizard walks you through it)
   - Copy **Threads App ID** and **Threads App Secret** — you'll need these
     for step 4

## 2. Configure OAuth redirect URIs

Still under **Threads → Use cases → Access the Threads API → Settings**, add:

| Field | Value |
|---|---|
| Redirect Callback URL | `https://<your-host>/threads/callback` |
| Deauthorize Callback URL | `https://<your-host>/threads/callback` (same — Chatwoot handles both) |
| Data Deletion Callback URL | `https://<your-host>/threads/callback` |

Permissions to request (should show as "Advanced Access" for production):
- `threads_basic`
- `threads_content_publish`
- `threads_manage_replies`
- `threads_read_replies`
- `threads_manage_insights`
- `threads_keyword_search`

These are the exact scopes `Threads::IntegrationHelper::REQUIRED_SCOPES` asks
for. They're self-service in development mode; production requires App Review.

## 3. Configure the Threads webhook

Under **Threads → Webhooks** (distinct from the Messenger/IG webhooks page):

| Field | Value |
|---|---|
| Callback URL | `https://<your-host>/webhooks/threads` |
| Verify Token | (pick any secret string, e.g. `cw-threads-$(openssl rand -hex 16)`) |

Click **Verify and Save**. Meta hits `GET /webhooks/threads?hub.verify_token=…&hub.challenge=…`
and our `Webhooks::ThreadsController#verify` responds with the challenge when
the token matches `THREADS_VERIFY_TOKEN` in your Chatwoot global config.

Under **Webhook fields**, subscribe to:
- `replies`
- `mentions`
- `quotes`

## 4. Put the credentials into Chatwoot

Super Admin → **App Configs** → find and set:

| Key | Value |
|---|---|
| `THREADS_APP_ID` | From step 1 |
| `THREADS_APP_SECRET` | From step 1 |
| `THREADS_VERIFY_TOKEN` | The secret you picked in step 3 |
| `THREADS_API_VERSION` | `v1.0` (already pre-populated) |

Save, then restart your web + sidekiq workers so `GlobalConfigService` picks
the values up and the Vue inbox wizard surfaces the Threads tile.

## 5. Connect your first Threads inbox

1. Log into Chatwoot → **Settings → Inboxes → Add Inbox**.
2. You should now see a **Threads** tile alongside Instagram/TikTok. If not,
   the feature flag or config isn't loaded — see Troubleshooting.
3. Click it → **Continue with Threads** → authorize on threads.net.
4. You'll be redirected back. Chatwoot creates:
   - Parent inbox: `<your-username>` (for replies on your own threads)
   - Sub-inbox: `<your-username> - Mentions` (for mentions + quotes of you)
5. Assign agents to both inboxes.

## 6. Smoke test end-to-end

### 6a. Inbound reply
1. From a different Threads account, reply to one of your threads.
2. Within ~1 min, a conversation should appear in the **Replies** inbox
   tagged with a Threads post banner showing the root thread text.
3. Verify in Sidekiq logs: `Webhooks::ThreadsEventsJob` → `Webhooks::ThreadsReplyEventsJob`.

### 6b. Inbound mention / quote
1. From a different account, make a new thread containing `@your-username`
   or quote one of your threads.
2. Give Meta 5–15 minutes to index. The scheduled `Webhooks::ThreadsMentionsPollJob`
   (every 5 min) will pick it up if the real-time webhook didn't.
3. Conversation appears in **Mentions** sub-inbox with banner label
   "Your Account Was Mentioned" or "Your Thread Was Quoted".

### 6c. Outgoing reply
1. Open a conversation in the Replies inbox → type a reply → Send.
2. Check the message `source_id` gets populated (indicates Graph API 2-step
   publish succeeded).
3. Verify the reply actually appears on threads.net under the original thread.

### 6d. Token refresh
Manual trigger (won't actually refresh unless within 10 days of expiry):

```bash
bundle exec rails runner "Webhooks::ThreadsTokenRefreshJob.new.perform"
```

Scheduled daily at 03:00 UTC via `config/schedule.yml`.

---

## Troubleshooting

### "Threads tile doesn't appear in inbox creation"
- `window.chatwootConfig.threadsAppId` must be non-empty. Inspect in the
  browser DevTools console. If empty, `THREADS_APP_ID` isn't set or the
  web process wasn't restarted after saving it.
- `channel_threads` feature flag must be enabled. Default `enabled: true`
  from `config/features.yml`. Check **Super Admin → Features**.

### "Webhook verification failed"
Meta shows "The URL couldn't be validated". Two usual causes:
1. Your `THREADS_VERIFY_TOKEN` in Chatwoot doesn't match what you typed in
   the Meta dashboard. They must match **exactly** (watch for trailing
   whitespace).
2. Your Chatwoot isn't reachable from the public internet, or TLS is invalid.
   `curl -I https://<your-host>/webhooks/threads` should return 200.

### "Webhook is hit but no conversation appears"
Add the raw payload log (same pattern as IG):

```ruby
# app/controllers/webhooks/threads_controller.rb (already logs at INFO)
```

Tail `log/production.log` for `THREADS_WEBHOOK_RAW:` — confirms the shape
Meta is sending. If `object != "threads"`, the subscription is wrong.
If `changes[0].field` isn't `replies|mentions|quotes`, you subscribed to
the wrong fields in step 3.

### "Mentions webhook never fires but replies do"
Same Meta platform gating that affects Instagram `mentions`:

- The mentioning account's **Tag approval** setting can silently hold
  mentions for manual review. Go to Threads profile → Settings → Privacy
  → Tags and mentions → disable "Manually approve tags" on the receiving
  account.
- Caption mentions can take 5–15 min to index into Meta's mention API.
  The `Webhooks::ThreadsMentionsPollJob` scheduled every 5 min is the
  fallback — it hits `GET /{threads-user-id}/mentions` directly and
  backfills anything the webhook missed.
- Private mentioning accounts don't surface in either webhook or poll.

### "Outgoing reply fails with code 190"
Access token invalidated (user revoked app access, changed password, or
>60 days since last refresh with no refresh hit in the 10-day window).
`channel.authorization_error!` increments — after threshold, Reauthorizable
fires `threads_disconnect` email and sets `reauthorization_required: true`
on the inbox. The `Reauthorize.vue` CTA will then show in the inbox
settings; clicking it runs the OAuth flow again.

### "Token refresh fails silently"
Run:

```bash
bundle exec rails runner '
Channel::Threads.find_each do |c|
  puts "channel=#{c.id} expires_at=#{c.expires_at} updated_at=#{c.updated_at}"
  puts "  eligible=#{Threads::RefreshOauthTokenService.new(channel: c).send(:token_eligible_for_refresh?)}"
end'
```

The service only refreshes when all three of:
- token still valid (`Time.current < expires_at`)
- token is at least 24h old (`Time.current - updated_at >= 24.hours`)
- token expires within 10 days (`expires_at < 10.days.from_now`)

Outside that window the method is a no-op on purpose, per Meta's
"refresh once per 24h, not before 50 days in" guidance.

---

## Rollback

If you need to disable Threads without uninstalling:

1. Super Admin → **Features** → disable `channel_threads`
2. This hides the tile in the inbox wizard but leaves existing inboxes
   and webhook routes live

To fully remove:

```bash
bundle exec rails runner "Channel::Threads.find_each(&:destroy)"
bundle exec rails db:rollback STEP=1   # reverses the migration
```

The `before_destroy :unsubscribe` on `Channel::Threads` will fire
`DELETE /{threads-user-id}/subscribed_apps` before the row is removed,
cleanly deregistering from Meta.

---

## What's _not_ in this release (happy-path MVP scope)

- **Attachments on outgoing replies** — text-only. Adding `IMAGE`/`VIDEO`
  support requires uploading `media_url` first (Meta hosts the asset,
  not us), then setting `media_type=IMAGE` in the container.
- **Quote composition** — agents can't quote-reply a thread from Chatwoot.
  Supported inbound (recognized and banner-labeled), not outbound.
- **Insights / analytics** — `threads_manage_insights` scope is requested
  but we don't surface engagement data in the Chatwoot UI.
- **Story mentions / cross-posting** — out of scope for this integration;
  Threads has no stories.

Those are all additive; the model + webhook pipeline is ready to carry
them when product prioritizes.

