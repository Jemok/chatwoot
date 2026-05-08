# Webhook curl Examples

Ready-to-run `curl` examples for both verify and event calls for Messenger (Facebook) and Instagram webhooks.

---

## Messenger (Facebook) — `/bot`

> If `FB_APP_SECRET` is configured, every `POST /bot` request must include a valid `X-Hub-Signature` header computed from the **raw request body**. Unsigned `curl` requests will return `400` and will not create conversations.

### Signed POST helper (required when `FB_APP_SECRET` is set)

```bash
body='{"object":"page","entry":[{"id":"PAGE_ID","time":1458692752478,"messaging":[{"sender":{"id":"SENDER_PSID"},"recipient":{"id":"PAGE_ID"},"timestamp":1458692752478,"message":{"mid":"mid.1457764197618:41d102a3e1ae206a38","text":"Hello from Messenger!"}}]}]}'
signature=$(printf '%s' "$body" | openssl sha1 -hmac "$FB_APP_SECRET" | awk '{print $2}')

curl -X POST "https://YOUR_DOMAIN/bot" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature: sha1=$signature" \
  -d "$body"
```

### Verify token (GET — Meta sends this when you register the webhook)

```bash
curl -X GET "https://YOUR_DOMAIN/bot" \
  -G \
  --data-urlencode "hub.mode=subscribe" \
  --data-urlencode "hub.verify_token=YOUR_FB_VERIFY_TOKEN" \
  --data-urlencode "hub.challenge=CHALLENGE_CODE_12345"
```

### Inbound DM message (POST)

```bash
curl -X POST "https://YOUR_DOMAIN/bot" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "page",
    "entry": [
      {
        "id": "PAGE_ID",
        "time": 1458692752478,
        "messaging": [
          {
            "sender": { "id": "SENDER_PSID" },
            "recipient": { "id": "PAGE_ID" },
            "timestamp": 1458692752478,
            "message": {
              "mid": "mid.1457764197618:41d102a3e1ae206a38",
              "text": "Hello from Messenger!"
            }
          }
        ]
      }
    ]
  }'
```

### Feed/comment event (POST)

```bash
curl -X POST "https://YOUR_DOMAIN/bot" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "page",
    "entry": [
      {
        "id": "PAGE_ID",
        "time": 1458692752478,
        "changes": [
          {
            "field": "feed",
            "value": {
              "item": "comment",
              "verb": "add",
              "comment_id": "COMMENT_ID_123",
              "post_id": "POST_ID_456",
              "from": {
                "id": "USER_ID",
                "name": "John Doe"
              },
              "message": "Nice post!"
            }
          }
        ]
      }
    ]
  }'
```

### Mention event (POST)

```bash
curl -X POST "https://YOUR_DOMAIN/bot" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "page",
    "entry": [
      {
        "id": "PAGE_ID",
        "time": 1458692752478,
        "changes": [
          {
            "field": "mention",
            "value": {
              "item": "comment",
              "verb": "add",
              "comment_id": "COMMENT_ID_789",
              "post_id": "POST_ID_456",
              "sender_id": "USER_ID",
              "message": "Hey @PageName check this out"
            }
          }
        ]
      }
    ]
  }'
```

### Message echo (POST)

```bash
curl -X POST "https://YOUR_DOMAIN/bot" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "page",
    "entry": [
      {
        "id": "PAGE_ID",
        "time": 1458692752478,
        "messaging": [
          {
            "sender": { "id": "PAGE_ID" },
            "recipient": { "id": "RECIPIENT_PSID" },
            "timestamp": 1458692752478,
            "message": {
              "mid": "mid.echo.abc123",
              "text": "This is the agent reply echo",
              "is_echo": true,
              "app_id": 12345678
            }
          }
        ]
      }
    ]
  }'
```

---

## Instagram — `/webhooks/instagram`

### Verify token (GET — Meta sends this when you register the webhook)

```bash
curl -X GET "https://YOUR_DOMAIN/webhooks/instagram" \
  -G \
  --data-urlencode "hub.mode=subscribe" \
  --data-urlencode "hub.verify_token=YOUR_INSTAGRAM_VERIFY_TOKEN" \
  --data-urlencode "hub.challenge=CHALLENGE_CODE_12345"
```

> Token must match either `INSTAGRAM_VERIFY_TOKEN` or `IG_VERIFY_TOKEN` as stored in `InstallationConfig`.

### Inbound DM message (POST)

```bash
curl -X POST "https://YOUR_DOMAIN/webhooks/instagram" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "instagram",
    "entry": [
      {
        "id": "INSTAGRAM_USER_ID",
        "time": 1458692752478,
        "messaging": [
          {
            "sender": { "id": "SENDER_IGSID" },
            "recipient": { "id": "INSTAGRAM_USER_ID" },
            "timestamp": 1458692752478,
            "message": {
              "mid": "aWdic2lkX...",
              "text": "Hello from Instagram!"
            }
          }
        ]
      }
    ]
  }'
```

### Message echo (POST — triggers 2 second delayed job)

```bash
curl -X POST "https://YOUR_DOMAIN/webhooks/instagram" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "instagram",
    "entry": [
      {
        "id": "INSTAGRAM_USER_ID",
        "time": 1458692752478,
        "messaging": [
          {
            "sender": { "id": "INSTAGRAM_USER_ID" },
            "recipient": { "id": "SENDER_IGSID" },
            "timestamp": 1458692752478,
            "message": {
              "mid": "aWdic2lkX_echo_...",
              "text": "Agent reply echo",
              "is_echo": true
            }
          }
        ]
      }
    ]
  }'
```

### Story mention (POST)

```bash
curl -X POST "https://YOUR_DOMAIN/webhooks/instagram" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "instagram",
    "entry": [
      {
        "id": "INSTAGRAM_USER_ID",
        "time": 1458692752478,
        "messaging": [
          {
            "sender": { "id": "SENDER_IGSID" },
            "recipient": { "id": "INSTAGRAM_USER_ID" },
            "timestamp": 1458692752478,
            "message": {
              "mid": "aWdic2lkX_mention_...",
              "attachments": [
                {
                  "type": "story_mention",
                  "payload": {
                    "url": "https://www.instagram.com/stories/..."
                  }
                }
              ]
            }
          }
        ]
      }
    ]
  }'
```

---

## Quick reference

| Channel   | Verb   | Path                    | Purpose          |
|-----------|--------|-------------------------|------------------|
| Messenger | `GET`  | `/bot`                  | Token verification |
| Messenger | `POST` | `/bot`                  | DMs / echoes / feed / mentions |
| Instagram | `GET`  | `/webhooks/instagram`   | Token verification |
| Instagram | `POST` | `/webhooks/instagram`   | DMs / echoes / story mentions |

Replace `YOUR_DOMAIN` with your actual server URL — e.g. `https://app.chatwoot.com` or an ngrok tunnel during local development.

