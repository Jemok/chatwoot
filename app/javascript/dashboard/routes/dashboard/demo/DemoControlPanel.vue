<script setup>
import { ref, onMounted, computed } from 'vue';
import { useStore } from 'vuex';
const axios = window.axios;

const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

// Banking demo nav hub — none of the demo screens are wired into the main
// sidebar yet, so we expose them all here as one-click launchers.
const demoScreens = computed(() => {
  const base = `/app/accounts/${accountId.value}`;
  return [
    { label: 'Audit Trail', icon: '🛡️', path: `${base}/audit-trail` },
    { label: 'Security Dashboard', icon: '🚨', path: `${base}/security` },
    { label: 'Shifts Admin', icon: '⏰', path: `${base}/settings/shifts` },
    {
      label: 'Users & Lifecycle',
      icon: '👥',
      path: `${base}/settings/users-lifecycle`,
    },
    { label: 'Filtered Inbox', icon: '🔍', path: `${base}/filtered-inbox` },
    {
      label: 'Channel Performance',
      icon: '📈',
      path: `${base}/reports/channel-performance`,
    },
    { label: 'NPS Report', icon: '📊', path: `${base}/reports/nps` },
    { label: 'Architecture View', icon: '🏛️', path: `${base}/architecture` },
    { label: 'Demo Coverage Map', icon: '🗺️', path: `${base}/demo-coverage` },
  ];
});

const overview = ref(null);
const lastResult = ref(null);
const lastError = ref(null);
const busy = ref(false);
const customPayload = ref({});

const SCENARIOS = [
  {
    kind: 'inbound_message',
    label: 'New Inbound DM',
    description: 'Creates a real DM conversation in the first DM-queue inbox.',
    icon: '💬',
    color: 'bg-emerald-500',
  },
  {
    kind: 'public_comment',
    label: 'Public Comment',
    description:
      'Drops a comment into a Public sub-inbox (FB/IG public queue).',
    icon: '📝',
    color: 'bg-sky-500',
  },
  {
    kind: 'mention',
    label: 'External Mention',
    description:
      'Inbound mention from outside owned pages — lands in Mentions queue.',
    icon: '📣',
    color: 'bg-indigo-500',
  },
  {
    kind: 'offensive_comment',
    label: 'Offensive Comment',
    description:
      'Public comment auto-tagged "needs-moderation" — try Hide/Delete.',
    icon: '🚫',
    color: 'bg-rose-500',
  },
  {
    kind: 'old_whatsapp',
    label: 'WhatsApp >24h',
    description:
      'Aged WA conversation — agent reply will be blocked & require template.',
    icon: '⏰',
    color: 'bg-amber-500',
  },
  {
    kind: 'old_facebook',
    label: 'Facebook DM >7d',
    description: 'Aged FB DM — agent reply will be blocked by 7-day policy.',
    icon: '📅',
    color: 'bg-orange-500',
  },
  {
    kind: 'identity_link',
    label: 'Identity Link Suggestion',
    description:
      'Two contacts share a phone — supervisor merge suggestion appears.',
    icon: '🔗',
    color: 'bg-violet-500',
  },
  {
    kind: 'collision',
    label: 'Collision / Lock',
    description: 'Locks the most recent conversation as another agent.',
    icon: '🔒',
    color: 'bg-slate-600',
  },
  {
    kind: 'denied_action',
    label: 'Denied Access',
    description:
      'Logs a denied/unauthorized action attempt to the security feed.',
    icon: '🛑',
    color: 'bg-red-600',
  },
  {
    kind: 'failed_login',
    label: 'Suspicious Login',
    description: 'Logs a synthetic failed-login burst from a suspicious IP.',
    icon: '⚠️',
    color: 'bg-yellow-600',
  },
  {
    kind: 'shift_end_force_logout',
    label: 'End Shift (force-logout)',
    description:
      "Ends a non-admin agent's shift right now — their dashboard goes off-duty.",
    icon: '🚪',
    color: 'bg-fuchsia-600',
  },
];

const fetchOverview = async () => {
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${accountId.value}/demo/overview`
    );
    overview.value = data;
  } catch (e) {
    lastError.value = e.response?.data?.error || e.message;
  }
};

const trigger = async kind => {
  busy.value = true;
  lastError.value = null;
  lastResult.value = null;
  try {
    const { data } = await axios.post(
      `/api/v1/accounts/${accountId.value}/demo/simulate`,
      { kind, payload: customPayload.value }
    );
    lastResult.value = data;
    await fetchOverview();
  } catch (e) {
    lastError.value = e.response?.data?.error || e.message;
  } finally {
    busy.value = false;
  }
};

onMounted(fetchOverview);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6">
      <h1 class="text-2xl font-semibold text-n-slate-12">
        🎬 Demo Control Panel
      </h1>
      <p class="text-sm text-n-slate-11 mt-1">
        Trigger live, in-app demo events. Each action creates real
        conversations, contacts, locks, or audit entries — nothing is mocked.
      </p>
    </header>

    <section class="mb-8">
      <h2
        class="text-sm font-semibold uppercase tracking-wider text-n-slate-10 mb-3"
      >
        🚀 Demo screens (no sidebar links yet — open from here)
      </h2>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
        <router-link
          v-for="s in demoScreens"
          :key="s.path"
          :to="s.path"
          class="flex items-center gap-2 px-3 py-2 rounded-lg bg-n-solid-1 border border-n-weak hover:border-n-strong text-sm text-n-slate-12"
        >
          <span class="text-lg">{{ s.icon }}</span>
          <span>{{ s.label }}</span>
        </router-link>
      </div>
    </section>

    <section v-if="overview" class="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
      <div
        v-for="(value, key) in overview.counts"
        :key="key"
        class="bg-n-solid-1 rounded-xl p-4 border border-n-weak"
      >
        <div class="text-xs uppercase text-n-slate-10 tracking-wider">
          {{ key.replace(/_/g, ' ') }}
        </div>
        <div class="text-2xl font-semibold text-n-slate-12 mt-1">
          {{ value }}
        </div>
      </div>
    </section>

    <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <button
        v-for="s in SCENARIOS"
        :key="s.kind"
        :disabled="busy"
        class="text-left rounded-xl p-5 bg-n-solid-1 border border-n-weak hover:border-n-strong transition disabled:opacity-50"
        @click="trigger(s.kind)"
      >
        <div class="flex items-center gap-3 mb-2">
          <span
            :class="[
              s.color,
              'w-10 h-10 rounded-lg flex items-center justify-center text-xl',
            ]"
            >{{ s.icon }}
          </span>
          <h3 class="font-semibold text-n-slate-12">{{ s.label }}</h3>
        </div>
        <p class="text-sm text-n-slate-11">{{ s.description }}</p>
      </button>
    </section>

    <section
      v-if="lastResult"
      class="mt-6 rounded-lg bg-emerald-50 border border-emerald-200 p-4"
    >
      <div class="text-sm font-semibold text-emerald-800 mb-1">
        ✅ {{ lastResult.kind }} simulated successfully
      </div>
      <pre class="text-xs text-emerald-900 overflow-auto">{{
        lastResult.result
      }}</pre>
    </section>

    <section
      v-if="lastError"
      class="mt-6 rounded-lg bg-rose-50 border border-rose-200 p-4"
    >
      <div class="text-sm font-semibold text-rose-800 mb-1">⚠️ Error</div>
      <pre class="text-xs text-rose-900 overflow-auto">{{ lastError }}</pre>
    </section>

    <section v-if="overview && overview.recent_violations.length" class="mt-8">
      <h2 class="text-lg font-semibold text-n-slate-12 mb-3">
        Recent Policy / Security Events
      </h2>
      <div class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
            <tr>
              <th class="text-left px-3 py-2">When</th>
              <th class="text-left px-3 py-2">Policy</th>
              <th class="text-left px-3 py-2">Action</th>
              <th class="text-left px-3 py-2">IP</th>
              <th class="text-left px-3 py-2">Details</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="v in overview.recent_violations"
              :key="v.id"
              class="border-t border-n-weak"
            >
              <td class="px-3 py-2 text-n-slate-11">{{ v.created_at }}</td>
              <td class="px-3 py-2">
                <span
                  class="inline-block px-2 py-0.5 rounded bg-rose-100 text-rose-800 text-xs"
                >
                  {{ v.policy }}
                </span>
              </td>
              <td class="px-3 py-2 text-n-slate-12">
                {{ v.action_attempted }}
              </td>
              <td class="px-3 py-2 text-n-slate-11">{{ v.request_ip }}</td>
              <td class="px-3 py-2 text-n-slate-11 max-w-md truncate">
                {{ v.details }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>
