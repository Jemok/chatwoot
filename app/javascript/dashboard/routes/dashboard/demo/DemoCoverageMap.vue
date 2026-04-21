<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';

const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);
const link = path => `/app/accounts/${accountId.value}${path}`;

// Each row maps a demo requirement to its live entry point in the app.
// Status: live | api | simulated
const SECTIONS = [
  {
    key: 'A',
    title: 'Dashboard / Usability / Executive View',
    items: [
      {
        id: 'A1',
        label: 'Unified multi-channel inbox',
        status: 'live',
        go: '/conversations',
      },
      {
        id: 'A2',
        label: 'Real-time channel performance',
        status: 'live',
        go: '/reports/channel-performance',
      },
      {
        id: 'A3',
        label: 'Minimal-click dashboard',
        status: 'live',
        go: '/conversations',
      },
      {
        id: 'A5',
        label: 'Executive landing — Demo coverage map',
        status: 'live',
        go: '/demo-coverage',
      },
    ],
  },
  {
    key: 'B',
    title: 'Queues / Source Separation',
    items: [
      {
        id: 'B6',
        label: 'FB Inbox vs FB Public Queue (sub-inboxes)',
        status: 'live',
        go: '/settings/inboxes/list',
      },
      {
        id: 'B7',
        label: 'Channel queues (FB pub/inbox, X, TikTok, WA)',
        status: 'live',
        go: '/settings/inboxes/list',
      },
      {
        id: 'B8',
        label: 'Source/type split per channel',
        status: 'live',
        api: 'GET /api/v1/.../conversations?source_type=comments',
      },
      {
        id: 'B9',
        label: 'Wall posts vs DMs separately',
        status: 'live',
        go: '/conversations',
      },
    ],
  },
  {
    key: 'C',
    title: 'Assignment / Resolution / Visibility',
    items: [
      {
        id: 'C10',
        label: 'Supervisor → agent assignment',
        status: 'live',
        go: '/conversations',
      },
      {
        id: 'C11',
        label: 'Track to resolution',
        status: 'live',
        go: '/reports/overview',
      },
      {
        id: 'C12',
        label: 'Resolved exits open queue',
        status: 'live',
        go: '/conversations',
      },
      {
        id: 'C13',
        label: 'Resolved kept in audit',
        status: 'live',
        go: '/audit-trail',
      },
    ],
  },
  {
    key: 'D',
    title: 'Reply / Attachment / Moderation',
    items: [
      {
        id: 'D15',
        label: 'Real-time replies',
        status: 'live',
        go: '/conversations',
      },
      { id: 'D16', label: 'Attachments', status: 'live', go: '/conversations' },
      {
        id: 'D17',
        label: 'Edit/delete/hide replies (audit-preserved)',
        status: 'live',
        go: '/audit-trail',
      },
      {
        id: 'D18',
        label: 'Hide/delete offensive FB messages',
        status: 'simulated',
        api: 'POST .../messages/:id/moderate?moderation_action=hide  (MODERATION_SIMULATED=true)',
      },
      {
        id: 'D19',
        label: 'Moderate IG / TikTok comments',
        status: 'simulated',
        api: 'POST .../messages/:id/moderate (IG live, TikTok pending API)',
      },
      {
        id: 'D20',
        label: 'Block/restrict abusive profiles',
        status: 'live',
        go: '/contacts',
      },
    ],
  },
  {
    key: 'E',
    title: 'Policy Enforcement',
    items: [
      {
        id: 'E21',
        label: 'WhatsApp >24h: free-form blocked, template required',
        status: 'live',
        go: '/demo',
      },
      {
        id: 'E22',
        label: 'Facebook inbox >7d: non-compliant reply blocked',
        status: 'live',
        go: '/demo',
      },
    ],
  },
  {
    key: 'F',
    title: 'Listening / Mentions',
    items: [
      {
        id: 'F23',
        label: 'Mentions outside owned pages (X/TikTok/IG/FB)',
        status: 'live',
        go: '/settings/inboxes/list',
      },
      {
        id: 'F24',
        label: 'Route mentions into mention sub-inboxes',
        status: 'live',
        go: '/conversations',
      },
    ],
  },
  {
    key: 'G',
    title: 'Search / Filter / Stream Control',
    items: [
      {
        id: 'G25',
        label: 'Search by name/handle',
        status: 'live',
        go: '/search',
      },
      {
        id: 'G26',
        label: 'Keyword search in messages',
        status: 'live',
        go: '/search',
      },
      {
        id: 'G27',
        label: 'Sort newest↔oldest toggle',
        status: 'live',
        api: 'GET .../conversations?sort_by=created_at_asc',
      },
      {
        id: 'G28',
        label: 'Filter by source/queue/status/agent/SLA/date',
        status: 'live',
        api: 'GET .../conversations?source_type=...&queue_kind=...',
      },
    ],
  },
  {
    key: 'H',
    title: 'Customer Profile / Identity',
    items: [
      {
        id: 'H29',
        label: 'Profile w/ CIF, masked account, channel handles',
        status: 'live',
        go: '/contacts',
      },
      {
        id: 'H30',
        label: 'Cross-channel link via mobile (suggester)',
        status: 'live',
        go: '/demo',
      },
      {
        id: 'H31',
        label: 'One unified profile across channels',
        status: 'live',
        go: '/contacts',
      },
      {
        id: 'H32',
        label: 'Cross-channel history',
        status: 'live',
        go: '/contacts',
      },
    ],
  },
  {
    key: 'I',
    title: 'Collaboration / Collision Prevention',
    items: [
      {
        id: 'I33',
        label: 'Viewing indicator',
        status: 'live',
        go: '/conversations',
      },
      {
        id: 'I34',
        label: 'Typing indicator',
        status: 'live',
        go: '/conversations',
      },
      {
        id: 'I35',
        label: 'Prevent duplicate replies',
        status: 'live',
        go: '/demo',
      },
      {
        id: 'I36',
        label: 'Block multiple responders (lock)',
        status: 'live',
        go: '/demo',
      },
      {
        id: 'I37',
        label: 'Supervisor takeover',
        status: 'live',
        go: '/conversations',
      },
      {
        id: 'I38',
        label: 'Lock TTL / inactivity release',
        status: 'live',
        api: '2 min TTL; 60s heartbeat refresh',
      },
    ],
  },
  {
    key: 'J',
    title: 'Permissions / Users / Shifts / Access',
    items: [
      {
        id: 'J39',
        label: 'RBAC / role-based access',
        status: 'live',
        go: '/settings/agents/new',
      },
      {
        id: 'J40',
        label: 'Shift schedules / on-duty controls',
        status: 'live',
        go: '/settings/shifts',
      },
      {
        id: 'J41',
        label: 'Block unauthorized access (Rack::Attack + audit)',
        status: 'live',
        go: '/security',
      },
      { id: 'J42', label: 'Role-specific landing', status: 'live', go: '/' },
      {
        id: 'J43',
        label: 'Mask sensitive data by default',
        status: 'live',
        go: '/contacts',
      },
    ],
  },
  {
    key: 'K',
    title: 'Audit / Security / Suspicious Activity',
    items: [
      {
        id: 'K44',
        label: 'Audit trail (replies/moderation/assignment/denied)',
        status: 'live',
        go: '/audit-trail',
      },
      {
        id: 'K45',
        label: 'View deleted responses internally',
        status: 'live',
        go: '/audit-trail',
      },
      {
        id: 'K46',
        label: 'Suspicious activity monitoring',
        status: 'live',
        go: '/security',
      },
      {
        id: 'K47',
        label: 'Security dashboard + response controls',
        status: 'live',
        go: '/security',
      },
    ],
  },
  {
    key: 'L',
    title: 'Reporting',
    items: [
      {
        id: 'L48',
        label: 'CSAT reports',
        status: 'live',
        go: '/reports/overview',
      },
      { id: 'L49', label: 'NPS reports', status: 'live', go: '/reports/nps' },
      {
        id: 'L50',
        label: 'Channel performance dashboards',
        status: 'live',
        go: '/reports/channel-performance',
      },
      {
        id: 'L51',
        label: 'Resolution tracking dashboards',
        status: 'live',
        go: '/reports/overview',
      },
    ],
  },
  {
    key: 'M',
    title: 'Demo Support Tooling',
    items: [
      {
        id: 'M52',
        label: 'Demo Control Panel — 10 simulators',
        status: 'live',
        go: '/demo',
      },
      {
        id: 'M53',
        label: 'Demo coverage map (this page)',
        status: 'live',
        go: '/demo-coverage',
      },
      {
        id: 'M54',
        label: 'Architecture view',
        status: 'live',
        go: '/architecture',
      },
    ],
  },
];

const STATUS_STYLE = {
  live: 'bg-emerald-100 text-emerald-800',
  api: 'bg-sky-100 text-sky-800',
  simulated: 'bg-amber-100 text-amber-800',
};
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6">
      <h1 class="text-2xl font-semibold text-n-slate-12">
        🗺️ Demo Coverage Map
      </h1>
      <p class="text-sm text-n-slate-11 mt-1">
        Every banking-demo requirement mapped to a live entry point in the app.
        Click any row to jump to the screen that demonstrates it.
      </p>
    </header>

    <section v-for="s in SECTIONS" :key="s.key" class="mb-6">
      <h2
        class="text-sm font-semibold uppercase tracking-wider text-n-slate-10 mb-2"
      >
        {{ s.key }} · {{ s.title }}
      </h2>
      <div class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden">
        <div
          v-for="i in s.items"
          :key="i.id"
          class="flex items-center justify-between gap-4 px-4 py-2 border-t border-n-weak first:border-t-0"
        >
          <div class="flex items-center gap-3 min-w-0 flex-1">
            <span class="text-[10px] font-mono text-n-slate-10 w-10">{{
              i.id
            }}</span>
            <span class="text-sm text-n-slate-12 truncate">{{ i.label }}</span>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <span
              :class="[
                'text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wider',
                STATUS_STYLE[i.status],
              ]"
            >
              {{ i.status }}
            </span>
            <a
              v-if="i.go"
              :href="link(i.go)"
              class="text-xs px-2 py-1 rounded bg-n-solid-2 hover:bg-n-solid-3 text-n-slate-12"
            >
              Open →
            </a>
            <code
              v-else-if="i.api"
              class="text-[10px] text-n-slate-10 font-mono max-w-md truncate"
              >{{ i.api }}
            </code>
          </div>
        </div>
      </div>
    </section>

    <p class="text-xs text-n-slate-10 mt-4">
      <strong>Legend:</strong>
      <span class="ml-2"
        ><span class="inline-block w-2 h-2 rounded bg-emerald-500" /> live</span
      >
      <span class="ml-2"
        ><span class="inline-block w-2 h-2 rounded bg-sky-500" /> API
        endpoint</span
      >
      <span class="ml-2"
        ><span class="inline-block w-2 h-2 rounded bg-amber-500" /> honest
        simulation</span
      >
    </p>
  </div>
</template>
