<script setup>
// Static high-level architecture page. Pure SVG + tailwind, no JS dependencies.
// Renders the four layers of the banking-demo platform built on Chatwoot.
const LAYERS = [
  {
    name: 'Channels',
    color: 'bg-sky-50 border-sky-200',
    label: 'bg-sky-100 text-sky-800',
    items: [
      'Facebook Page (DM + Public + Mentions + Visitor Posts)',
      'Instagram (DM + Public + Mentions)',
      'X / Twitter (DMs + Mentions)',
      'WhatsApp Cloud + Twilio WA',
      'TikTok · Threads · LinkedIn · YouTube · App/Play Store',
      'Email · SMS · API · Webhooks',
    ],
  },
  {
    name: 'Ingest & Routing',
    color: 'bg-violet-50 border-violet-200',
    label: 'bg-violet-100 text-violet-800',
    items: [
      'Channel webhook controllers → SidekIq jobs',
      'Webhooks::*EventsJob routes to sub-inbox by surface',
      'ContactInboxWithContactBuilder → Conversation → Message',
      'Wisper Dispatcher (sync + async) → Listeners',
    ],
  },
  {
    name: 'Domain (extended Chatwoot)',
    color: 'bg-emerald-50 border-emerald-200',
    label: 'bg-emerald-100 text-emerald-800',
    items: [
      'Inbox + queue_kind + source_type (banking demo)',
      'Conversation.source_type · ConversationLock · MessageWindowService',
      'Contact.banking_attributes (CIF, masked acct, KYC) + IdentityLinkSuggestion',
      'PolicyViolationLog · ModeratedMessages · ContactBlocklist',
      'Shift / on-duty controls · Role-based landing',
    ],
  },
  {
    name: 'Presentation',
    color: 'bg-amber-50 border-amber-200',
    label: 'bg-amber-100 text-amber-800',
    items: [
      'Vue 3 SPA (dashboard) + Pinia stores (locks, calls)',
      'ActionCable RoomChannel — typing/viewing/lock broadcasts',
      'Demo Control Panel · Audit Trail · Security · Channel Perf · NPS · Coverage Map · Architecture',
    ],
  },
];

const FLOWS = [
  {
    from: 'External Platform',
    to: 'Webhook controller',
    label: 'POST /webhooks/...',
  },
  { from: 'Webhook controller', to: 'EventsJob (sidekiq)', label: 'enqueue' },
  {
    from: 'EventsJob',
    to: 'Sub-inbox (Public/Mentions/DM)',
    label: 'route by surface',
  },
  { from: 'Sub-inbox', to: 'Conversation + Message', label: 'create' },
  { from: 'Conversation', to: 'Dispatcher', label: 'CONVERSATION_CREATED' },
  { from: 'Dispatcher', to: 'ActionCableListener', label: 'broadcast' },
  { from: 'ActionCableListener', to: 'Vue SPA', label: 'WebSocket' },
];
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6">
      <h1 class="text-2xl font-semibold text-n-slate-12">
        🏛️ Architecture View
      </h1>
      <p class="text-sm text-n-slate-11 mt-1">
        High-level layers of the banking-demo platform — built by extending
        Chatwoot, not replacing it.
      </p>
    </header>

    <!-- Layer stack -->
    <section class="space-y-3 mb-8">
      <div
        v-for="(layer, idx) in LAYERS"
        :key="layer.name"
        :class="['rounded-xl border-2 p-4', layer.color]"
      >
        <div class="flex items-center gap-3 mb-2">
          <span
            :class="[
              'text-xs font-bold px-2 py-0.5 rounded uppercase tracking-wider',
              layer.label,
            ]"
          >
            Layer {{ idx + 1 }}
          </span>
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ layer.name }}
          </h2>
        </div>
        <ul
          class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-1 text-sm text-n-slate-12"
        >
          <li
            v-for="item in layer.items"
            :key="item"
            class="flex items-start gap-2"
          >
            <span class="text-n-slate-10">▸</span>
            <span>{{ item }}</span>
          </li>
        </ul>
      </div>
    </section>

    <!-- Inbound flow -->
    <section class="mb-8">
      <h2 class="text-lg font-semibold text-n-slate-12 mb-3">
        Inbound Message Flow
      </h2>
      <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
        <div class="flex flex-wrap items-center gap-2 text-sm">
          <template v-for="(f, i) in FLOWS" :key="i">
            <div
              class="px-3 py-2 rounded-lg bg-n-solid-2 border border-n-weak font-medium text-n-slate-12"
            >
              {{ f.from }}
            </div>
            <div class="flex flex-col items-center text-[10px] text-n-slate-10">
              <span>↳ {{ f.label }}</span>
              <span class="text-base">→</span>
            </div>
            <div
              v-if="i === FLOWS.length - 1"
              class="px-3 py-2 rounded-lg bg-emerald-100 border border-emerald-300 font-medium text-emerald-900"
            >
              {{ f.to }}
            </div>
          </template>
        </div>
      </div>
    </section>

    <!-- Trust boundaries -->
    <section class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="rounded-xl border border-rose-200 bg-rose-50 p-4">
        <h3 class="text-sm font-semibold text-rose-900 mb-2">
          🛡 Policy enforcement
        </h3>
        <ul class="text-xs text-rose-900 space-y-1">
          <li>WhatsApp 24h — MessagesController guard</li>
          <li>Facebook 7d — MessagesController guard</li>
          <li>Conversation lock — MessagesController guard</li>
          <li>RBAC — Pundit policies + admin guards</li>
        </ul>
      </div>
      <div class="rounded-xl border border-amber-200 bg-amber-50 p-4">
        <h3 class="text-sm font-semibold text-amber-900 mb-2">
          🕵 Audit & security
        </h3>
        <ul class="text-xs text-amber-900 space-y-1">
          <li>PolicyViolationLog — single audit feed</li>
          <li>Moderated messages — original_content preserved</li>
          <li>Account-number reveal — admin-only + logged</li>
          <li>Rack::Attack — failed-login throttle</li>
        </ul>
      </div>
      <div class="rounded-xl border border-violet-200 bg-violet-50 p-4">
        <h3 class="text-sm font-semibold text-violet-900 mb-2">
          🎬 Demo tooling
        </h3>
        <ul class="text-xs text-violet-900 space-y-1">
          <li>Demo Control Panel — 10 simulators</li>
          <li>MODERATION_SIMULATED env flag</li>
          <li>Coverage map / architecture view</li>
          <li>All simulators write real records</li>
        </ul>
      </div>
    </section>
  </div>
</template>
