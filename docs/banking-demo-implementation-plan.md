# Banking Demo — End-to-End Implementation Plan

> Approved working contract for the 10 demo features + sidebar group. See per-feature sections for current state, gaps, file-level build plan, and caveats. Implementation will proceed in the priority order at the bottom.

## Conventions (apply to every change)
- Tailwind only, no scoped CSS.
- Vue: Composition API + `<script setup>`. Use `window.axios` (auth headers attached) — never `import axios from 'axios'`.
- Backend layering: controllers thin → builders/services/finders/listeners. Pundit on every API resource. Listeners subscribe via dispatchers (no new ActionCable channels — broadcast through `RoomChannel` via `ActionCableBroadcastJob`).
- i18n: only `en.yml` and `en.json` trees.
- Routes: `frontendURL('accounts/:accountId/...')` for SPA, `config/routes.rb` for API.
- Migrations on hot tables: `disable_ddl_transaction!` + `algorithm: :concurrently`.
- Enterprise: end OSS files with `prepend_mod_with('ClassName')` if EE may extend.

---

## Feature 1 — Shift-driven Create / Disable / Suspend Users

### Current state
- `Shift` model + `STATUSES` + `Shift.user_on_duty?` + `Shift.shift_enforcement_active?`.
- `ShiftsController` (CRUD + `on_duty`) gated by `ensure_administrator!` — not Pundit.
- Off-shift reply block in `MessagesController#enforce_shift!` writes `policy_violation_logs` (`denied_action`).
- `ShiftsAdmin.vue` page exists.

### Gaps
- Shift state is not tied to user lifecycle (create/disable/suspend).
- No status badge on agent profile / sidebar.
- No forced-logout / reply disable on shift end.
- Shift CRUD uses ad-hoc admin check (not Pundit).
- No recurring/weekly shift creation.
- No audit for admin user-lifecycle actions.

### Build plan
**Backend**
- `ShiftPolicy < ApplicationPolicy` (CRUD = admin; `on_duty?` = any agent). Replace `ensure_administrator!` with `authorize`.
- `Shifts::EnforcementService` → `:on_duty | :off_shift | :suspended | :disabled`.
- `Shifts::ScheduleSweepJob` (Sidekiq cron, 1 min): set ended-shift agents `availability=offline`, broadcast `user.shift.ended` via `ActionCableBroadcastJob`.
- `AgentsController#suspend|reinstate` — suspension = `confirmed_at=nil`, revoke `access_tokens`, rotate `pubsub_token`. Audited as `policy='user_lifecycle'`.
- Migration `add_recurrence_to_shifts.rb` (small table — plain): `weekday`, `recurrence ('once'|'weekly')`, `timezone`.
- `Shifts::Builder` to expand recurrence.
- Extend `PolicyViolationLog::POLICIES` with `'user_lifecycle'`.

**Frontend**
- New page `dashboard/routes/dashboard/demo/UsersLifecycle.vue` (admin): users list + status pill + Suspend / Reinstate / Disable + assign-shift modal with recurrence.
- Extend `ShiftsAdmin.vue` with weekly recurrence picker + bulk generate.
- New composable `useShiftStatus.js` (poll `/shifts/on_duty` every 60s + listen for `user.shift.ended`).
- New Pinia store `dashboard/stores/shifts.js`.
- Status pill in profile menu.
- Simulator kind `shift_end_force_logout`.

### Permissions
`ShiftPolicy` (admin), `AgentPolicy#suspend?` (admin).

### Audit
`PolicyViolationLog` policy `'user_lifecycle'` (suspend/reinstate/disable/shift_force_logout). Existing `'denied_action'` for blocked off-shift reply.

### Real-time
`user.shift.ended`, `user.suspended` via `ActionCableListener`.

### Demo path
Run simulator `shift_end_force_logout` → agent's reply box disables + banner appears + audit row written.

### Caveats
- Force-logout cannot kill an SPA session instantly — banner + reply-box disable is the honest UX.
- Suspension affects login but in-flight tokens require explicit rotation.

---

## Feature 2 — Edit / Delete / Hide / Replace Replies (Cross-Channel)

### Current state
- `MessagesController#destroy` preserves `original_content`, audits.
- `Facebook::ModerationService`, `Instagram::ModerationService` exist but no controller route invokes them.
- No edit / replace / follow-up workflow.
- AuditTrail.vue already shows original-vs-current.

### Gaps
- No POST routes to invoke moderation services from UI.
- No "follow-up correction" workflow for channels lacking edit (WA/SMS/Email/X DM).
- No role gating on destroy (any agent today).
- No reason-required dialog.

### Build plan
**Backend**
- New routes nested under `messages`: `POST :id/moderate`, `POST :id/replace`, `POST :id/follow_up`.
- `Messages::ModerationService` (dispatcher) → channel-specific service; for unsupported channels returns `simulated:true`, updates local state + audit only.
- `Messages::ReplacementService` — preserves `original_content`, requires `reason`, audits `policy='moderation_action'` action `'replace'`.
- `Messages::FollowUpCorrectionService` — creates new outgoing message linked via `content_attributes['corrects_message_id']`.
- New `MessagePolicy` (does not exist today): `destroy?`, `moderate?`, `replace?`, `follow_up?` → admin only; `create?` → any agent. Wire `authorize @message, :moderate?`.
- `params[:reason]` required on destroy/moderate/replace.

**Frontend**
- `dashboard/components/widgets/conversation/MessageActionsMenu.vue` — Edit-Replace / Hide / Unhide / Delete / Follow-up correction (rendered conditionally by channel + admin role).
- `MessageActionReasonDialog.vue` reason modal.
- Mount in existing message bubble.
- API helper `dashboard/api/messageModeration.js` (window.axios).
- i18n `CONVERSATION.MESSAGE_ACTIONS.*`.

### Audit
`policy='moderation_action'`, `action_attempted ∈ delete|hide|unhide|replace|follow_up`, with reason + simulated flag.

### Demo path
`offensive_comment` simulator → admin opens menu → Hide → row updates, AuditTrail shows entry.

### Caveats
- Email/WhatsApp/X/SMS — no edit API. UI must label "Replace (local only) + Follow-up correction sent to customer".
- FB/IG hide is real only with `MODERATION_SIMULATED=false` and `pages_manage_engagement` token. Show "Simulated" badge otherwise.

---

## Feature 3 — Hide / Unhide / Delete Offensive Facebook Messages

### Current state
- `Facebook::ModerationService` fully implemented.
- `offensive_comment` simulator exists.
- No HTTP route or UI button.

### Gaps
- Same as Feature 2 (route wiring) plus FB-specific UI.
- Bulk action in `FilteredInbox.vue` for multi-comment hide.

### Build plan
- Reuses Feature 2 routes/dispatcher.
- Add bulk-select column + "Hide selected" in `FilteredInbox.vue`.

### Caveats
- Once `delete` succeeds on Graph, no unhide possible. Disable Unhide when `moderation.action=='delete'`.

---

## Feature 4 — Block / Unblock Profiles (Facebook + X / Twitter)

### Current state
None.

### Gaps
- No `BlockedProfile` model/table.
- No block API for FB or X.
- No badge / restricted routing / management UI.

### Build plan
**Backend**
- Migration `create_blocked_profiles.rb`: `account_id`, `channel_type`, `platform_user_id`, `contact_id?`, `reason`, `blocked_until`, `blocked_by_user_id`, timestamps. Unique index on `(account_id, channel_type, platform_user_id)`.
- `BlockedProfile` model.
- `Facebook::BlockProfileService`, `X::BlockProfileService`, `Profiles::BlockingService` dispatcher (simulated when API unavailable).
- `BlockedProfileListener` on `message.created`: if active block matches sender, label conversation `restricted`, skip auto-assign, audit `'denied_action'`.
- `Api::V1::Accounts::BlockedProfilesController` (index/create/destroy) + `BlockedProfilePolicy` (admin) + routes.
- Extend `PolicyViolationLog::POLICIES` with `'profile_block'`.

**Frontend**
- `dashboard/routes/dashboard/demo/BlockedProfiles.vue` (list + add + remove + reason + duration).
- `ContactBlockedBadge.vue` in contact header.
- Red banner in conversation header for blocked-profile threads.
- API helper `dashboard/api/blockedProfiles.js`.
- Simulator kind `block_profile`.
- i18n `BLOCKED_PROFILES.*`.

### Audit
`policy='profile_block'` on block/unblock; `policy='denied_action'` on inbound from blocked profile.

### Real-time
Broadcast `profile.blocked` / `profile.unblocked` to refresh badges.

### Demo path
Simulator `block_profile` → block contact → next inbound from them shows restricted routing + audit row.

### Caveats
- X v2 `POST /users/:id/blocking` requires user-context OAuth and is being deprecated — mark **simulated** unless creds present.
- FB Page-level user blocks need `pages_manage_metadata`.

---

## Feature 5 — Audit-Trail Viewer

### Current state
- `PolicyViolationLog` table + `ModeratedMessagesController` + `AuditTrail.vue` (filters partial).

### Gaps
- Filtering by action/channel/user/date — partial UI checkboxes only.
- No unified audit for non-moderation admin actions.
- No "auditor" role.
- No pagination.

### Build plan
**Backend**
- Extend `POLICIES` to include `user_lifecycle`, `profile_block`, `routing_override`.
- Refactor `PolicyViolationLogsController` for `policy[]`, `channel_type`, `user_id`, `from`, `to`, `page` query params.
- `PolicyViolationLogPolicy` (admin OR custom role with `audit_logs:read`).
- Same updates for `ModeratedMessagesController`.
- Concurrent index migration `add_index_policy_violation_logs_on_account_created_at`.

**Frontend**
- Rebuild `AuditTrail.vue` with filter chips, date range pickers, server-side paging, deep-link to conversation.
- i18n `AUDIT_TRAIL.*` in new `auditTrail.json` (register in `i18n/index.js`).

### Real-time (optional)
Broadcast `policy_violation.created` for live tailing.

---

## Feature 6 — Real-time Typing + Viewing Presence

### Current state
- Typing supported via `CONVERSATION_TYPING_ON/OFF`.
- No per-conversation viewing presence.

### Gaps
- No `conversation.viewing_on/off` event.
- No client emit on conversation open/leave.
- No header avatars.

### Build plan
**Backend**
- Add `CONVERSATION_VIEWING_ON|OFF` to `lib/events/types.rb`.
- Extend `ActionCableListener` handlers.
- Endpoint `POST/DELETE conversations/:id/viewing` (mirror typing controller).

**Frontend**
- `dashboard/composables/useConversationPresence.js` — emit on mount/visibility-change/unmount with debounce.
- `ConversationViewerStack.vue` in conversation header.
- Extend ReplyBox typing display with viewer list.
- New Pinia `presence.js`.
- Subscribe to new events in `dashboard/helper/actionCable.js`.

### Permission
Reuse `ConversationPolicy#show?`.

### Real-time
Account-scoped pubsub via `ActionCableBroadcastJob` (`account.users.pluck(:pubsub_token)`).

### Demo path
Open same conversation in two browsers → see avatars + typing indicators.

### Caveats
- Debounce viewing_on to ≤ 1/sec/conversation.
- No new ActionCable channels.

---

## Feature 7 — Active Responder Lock (polish)

### Current state
- `ConversationLock` + controller + cable broadcast + `enforce_conversation_lock!` + `dashboard/stores/conversationLocks.js` already wired.

### Gaps
- Takeover uses ad-hoc admin check, not Pundit.
- TTL hard-coded (2 min).
- Takeover not audited.
- Need to confirm UI integration in ReplyBox.

### Build plan
**Backend**
- `ConversationLockPolicy` (show/create/destroy = participant; `takeover?` = admin).
- Extend `acquire!(supervisor_takeover: true)` to write audit row + broadcast `conversation.lock.takeover`.
- `ConversationLockSweepJob` (cron 1 min) — clean expired locks.

**Frontend**
- `useConversationLock.js` composable (acquire on open, heartbeat 60s, release on unmount/send).
- ReplyBox: disable when locked by another agent; show takeover button for admins.
- `LockedBanner.vue` with countdown.
- i18n `CONVERSATION.LOCK.*`.

### Audit
`'denied_action'` for collision attempts (existing); `lock_takeover` action label for takeovers.

---

## Feature 8 — Enforced Automatic Routing Mode

### Current state
- `Inbox.queue_kind`, `Inbox.source_type`, `Conversation.source_type` columns exist.
- Stock `automation_rules` table.
- No enforced toggle, no route-reason persistence, no banking-specific rule UI.

### Gaps
- Account flag `enforced_routing_enabled`.
- `automation_rules.enforced` boolean.
- Persist `route_reason` on conversation.
- Supervisor override endpoint + audit.
- Admin UI page for rule ordering + enforcement toggle.

### Build plan
**Backend**
- Migration `add_enforced_routing_to_accounts` + `add_enforced_to_automation_rules` (concurrent on the latter).
- `Routing::EnforcementService` invoked from new `EnforcedRoutingListener` on `Events::Types::CONVERSATION_CREATED` — runs before generic round-robin.
- `POST conversations/:id/route_override` audited as `policy='routing_override'`.
- `AutomationRulePolicy#enforce?` (admin).

**Frontend**
- New page `dashboard/routes/dashboard/demo/RoutingMode.vue` — toggle + drag-orderable rule list + per-rule enforced checkbox.
- ConversationHeader chip "Routed by Rule X" from `additional_attributes.route_reason`.
- i18n `ROUTING_MODE.*`.

### Demo path
Simulator `inbound_message` with `source_type=public_comment` → routes to "Public Comments" team automatically.

### Caveats
- Reusing `automation_rules` keeps UI consistent but locks event to `conversation_created`.
- Listener must run before round-robin.

---

## Feature 9 — CSAT and (especially) NPS

### Current state
- Stock CSAT exists.
- `NpsResponse` model + `NpsResponsesController` + `NpsReport.vue` (snapshot only).

### Gaps
- No NPS trend, no by-channel/by-agent drilldown, no comments tab, no CSV export, no Pundit.
- No public NPS submission endpoint.
- No banking-specific CSAT view.

### Build plan
**Backend**
- Extend `NpsResponsesController#index`: `group_by=day|week`, `by_inbox`, `by_agent`, `comments` modes.
- Public `POST /public/nps_responses?token=…` controller.
- `NpsResponsePolicy` (index/create=agent; `comments?`=admin).
- `Reports::CsatBankingService` for inbox.source_type / team breakdowns.

**Frontend**
- Rebuild `NpsReport.vue` with chart (existing chart.js wrapper) + breakdown bars + comments table (admin) + CSV export.
- New page `CsatBanking.vue`.
- Simulator kind `nps_response`.
- i18n `NPS.*`, `CSAT_BANKING.*`.

### Caveats
- Public endpoint needs CSRF skip + per-account token validation.

---

## Feature 10 — Cross-Channel Public Moderation (FB / IG / TikTok)

### Current state
- FB + IG `ModerationService` ready.
- No `Tiktok::ModerationService`.
- `MessagesController#moderation_service_class` knows only FB + IG.
- No moderation center UI.

### Gaps
- TikTok service.
- Moderate route wiring (Feature 2 covers).
- Unified Moderation Center UI across FB/IG/TT.

### Build plan
**Backend**
- `Tiktok::ModerationService` mirroring FB structure (simulated by default; real call when scopes present).
- Update `moderation_service_class` switch + `Messages::ModerationService` dispatcher.
- `GET messages/public_comments` cross-channel index (filter `conversation.source_type='public_comment'`, status filter).
- Webhook guard: if `message.moderated == true`, do not overwrite from inbound webhook.

**Frontend**
- New page `dashboard/routes/dashboard/demo/ModerationCenter.vue` — table with channel pill, simulated badge, bulk hide/delete + reason modal.
- i18n `MODERATION_CENTER.*` (new `moderation.json`, register in `i18n/index.js`).

### Caveats
- TikTok Comment Management API is gated behind Business approval — mostly simulated.
- IG hide on Threads-style posts requires `instagram_manage_comments`.

---

## Navigation — "Banking Demo" Sidebar Group

### Files
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` — append a new admin-gated group inside `menuItems` computed.
- `app/javascript/dashboard/i18n/locale/en/settings.json` — add `SIDEBAR.BANKING_DEMO` + child labels.
- `app/javascript/dashboard/routes/dashboard/demo/routes.js` — add new routes for `moderation_center`, `csat_banking`, `routing_mode_admin`, `blocked_profiles_admin`, `users_lifecycle`.

### Final structure (admin-only group)
Group: **Banking Demo** (icon `i-lucide-landmark`)

| Order | Label | Icon | Route name |
|---|---|---|---|
| 1 | Demo Control Panel | `i-lucide-sliders` | `demo_control_panel` |
| 2 | Moderation Center | `i-lucide-shield-alert` | `moderation_center` *(new)* |
| 3 | Filtered Inbox | `i-lucide-filter` | `filtered_inbox` |
| 4 | Audit Trail | `i-lucide-scroll-text` | `audit_trail` |
| 5 | Security Dashboard | `i-lucide-shield-check` | `security_dashboard` |
| 6 | Channel Performance | `i-lucide-activity` | `channel_performance` |
| 7 | NPS Report | `i-lucide-gauge` | `nps_report` |
| 8 | CSAT (Banking) | `i-lucide-smile` | `csat_banking` *(new)* |
| 9 | Routing Mode | `i-lucide-route` | `routing_mode_admin` *(new)* |
| 10 | Blocked Profiles | `i-lucide-user-x` | `blocked_profiles_admin` *(new)* |
| 11 | Users & Shifts | `i-lucide-calendar-clock` | `users_lifecycle` + `shifts_admin` |
| 12 | Demo Coverage Map | `i-lucide-map` | `demo_coverage_map` |
| 13 | Architecture View | `i-lucide-network` | `architecture_view` |

**Explicitly NOT in sidebar**: simulator scenarios (New Inbound DM, Public Comment, External Mention, Offensive Comment, WhatsApp >24h, Facebook DM >7d, Identity Link Suggestion, Collision/Lock, Denied Access, Suspicious Login). They remain only in `DemoControlPanel.vue`.

### Visibility
- Admin: full group.
- Supervisor: hidden (route `meta.permissions: ['administrator']`).
- Agent: hidden.

### Restart needed
- **Vite restart** required (route file imports + i18n JSON additions).
- Rails restart required if `config/routes.rb` changes.

---

## Priority-Ordered Implementation Checklist

1. **Feature 1 — Shift-driven user lifecycle**
2. **Feature 7 then Feature 6 — Lock polish + presence** (UX-critical for agent-collision demo)
3. **Feature 8 — Enforced routing**
4. **Feature 5 — Audit viewer (filters + paging + Pundit)**
5. **Feature 2 — Edit/delete/hide/replace cross-channel**
6. **Feature 3 — Facebook hide/delete UI**
7. **Feature 4 — Profile blocking (FB + X)**
8. **Feature 9 — CSAT + NPS dashboards**
9. **Feature 10 — Cross-channel moderation center**
10. **Navigation** — final sidebar group + icons + i18n

(Note: order swapped slightly from user's brief to put collision/typing right after shifts since they share the demo flow with two browser tabs, then routing before audit so audit can immediately show routing_override entries.)

---

## Open Questions Before Coding
1. Should the "Banking Demo" group be hidden behind a `feature_flags` flag (e.g. `banking_demo`) so non-demo accounts don't see it?
2. Keep `policy_violation_logs` as the single audit table (with extended `policy` enum) vs. introduce `audit_events` with structured `metadata` JSON?
3. For TikTok / X, prefer hard "API not configured → button disabled" UX, or always-allow simulated action with badge?

