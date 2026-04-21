<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useStore } from 'vuex';
const axios = window.axios;
import { downloadCsv } from './csvExport';

const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

const events = ref([]);
const error = ref(null);
const loading = ref(false);
let timer = null;

const fetchEvents = async () => {
  loading.value = true;
  error.value = null;
  try {
    const r = await axios.get(
      `/api/v1/accounts/${accountId.value}/policy_violation_logs?per_page=100`
    );
    events.value = r.data?.data ?? [];
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

const last24h = computed(() => {
  const cutoff = Date.now() - 24 * 3600 * 1000;
  return events.value.filter(e => new Date(e.created_at).getTime() > cutoff);
});

const counts = computed(() => {
  const out = {};
  last24h.value.forEach(e => {
    out[e.policy] = (out[e.policy] || 0) + 1;
  });
  return out;
});

const topIps = computed(() => {
  const map = {};
  last24h.value.forEach(e => {
    if (!e.request_ip) return;
    map[e.request_ip] = (map[e.request_ip] || 0) + 1;
  });
  return Object.entries(map)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5);
});

const policyBadge = p => {
  switch (p) {
    case 'suspicious_login':
      return 'bg-rose-100 text-rose-800';
    case 'denied_action':
      return 'bg-amber-100 text-amber-800';
    case 'whatsapp_24h':
    case 'facebook_7d':
      return 'bg-orange-100 text-orange-800';
    case 'moderation_action':
      return 'bg-violet-100 text-violet-800';
    default:
      return 'bg-n-slate-3 text-n-slate-11';
  }
};

const filterPolicy = ref('');

const filteredEvents = computed(() => {
  if (!filterPolicy.value) return events.value;
  return events.value.filter(e => e.policy === filterPolicy.value);
});

onMounted(() => {
  fetchEvents();
  timer = setInterval(fetchEvents, 15000);
});
onBeforeUnmount(() => timer && clearInterval(timer));

const exportEvents = () =>
  downloadCsv('security-events', filteredEvents.value, [
    'id',
    'created_at',
    'policy',
    'action_attempted',
    'conversation_id',
    'user_id',
    'request_ip',
    'details',
  ]);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          🛡️ Security Dashboard
        </h1>
        <p class="text-sm text-n-slate-11 mt-1">
          Real-time view of suspicious activity, denied actions, and policy
          violations. Auto-refreshes every 15 s.
        </p>
      </div>
      <div class="flex gap-2">
        <button
          type="button"
          class="px-3 py-1.5 rounded bg-n-solid-2 text-sm hover:bg-n-solid-3"
          :disabled="!filteredEvents.length"
          @click="exportEvents"
        >
          Export CSV
        </button>
        <button
          type="button"
          class="px-3 py-1.5 rounded bg-n-solid-2 text-sm hover:bg-n-solid-3"
          :disabled="loading"
          @click="fetchEvents"
        >
          {{ loading ? 'Loading…' : 'Refresh' }}
        </button>
      </div>
    </header>

    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>

    <!-- Tile counters -->
    <section class="grid grid-cols-2 md:grid-cols-5 gap-4 mb-6">
      <div
        v-for="key in [
          'suspicious_login',
          'denied_action',
          'whatsapp_24h',
          'facebook_7d',
          'moderation_action',
        ]"
        :key="key"
        class="rounded-xl bg-n-solid-1 border border-n-weak p-4 cursor-pointer"
        @click="filterPolicy = filterPolicy === key ? '' : key"
      >
        <div class="text-xs uppercase tracking-wider text-n-slate-10">
          {{ key.replace(/_/g, ' ') }}
        </div>
        <div
          :class="[
            'text-3xl font-semibold mt-1',
            counts[key] > 0 ? 'text-rose-600' : 'text-n-slate-12',
          ]"
        >
          {{ counts[key] || 0 }}
        </div>
        <div class="text-[10px] text-n-slate-10">last 24 h</div>
      </div>
    </section>

    <!-- Top noisy IPs -->
    <section
      v-if="topIps.length"
      class="rounded-xl border border-n-weak bg-n-solid-1 p-4 mb-6"
    >
      <h2
        class="text-sm font-semibold uppercase tracking-wider text-n-slate-10 mb-2"
      >
        Top noisy IPs (24 h)
      </h2>
      <div class="flex flex-wrap gap-2">
        <span
          v-for="[ip, c] in topIps"
          :key="ip"
          class="text-xs px-2 py-1 rounded bg-rose-50 border border-rose-200 text-rose-900"
        >
          {{ ip }}<span class="ml-1 font-semibold">·{{ c }}</span>
        </span>
      </div>
    </section>

    <!-- Filter chip -->
    <div v-if="filterPolicy" class="mb-2 text-xs">
      Filtering by:
      <span
        :class="[
          'ml-2 px-2 py-0.5 rounded uppercase tracking-wider',
          policyBadge(filterPolicy),
        ]"
      >
        {{ filterPolicy }}
      </span>
      <button class="ml-2 underline text-n-slate-11" @click="filterPolicy = ''">
        Clear
      </button>
    </div>

    <!-- Event feed -->
    <section
      class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
          <tr>
            <th class="text-left px-3 py-2">When</th>
            <th class="text-left px-3 py-2">Policy</th>
            <th class="text-left px-3 py-2">Action</th>
            <th class="text-left px-3 py-2">User</th>
            <th class="text-left px-3 py-2">IP</th>
            <th class="text-left px-3 py-2">Details</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="e in filteredEvents"
            :key="e.id"
            class="border-t border-n-weak"
          >
            <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
              {{ e.created_at }}
            </td>
            <td class="px-3 py-2">
              <span
                :class="[
                  'text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wider',
                  policyBadge(e.policy),
                ]"
              >
                {{ e.policy }}
              </span>
            </td>
            <td class="px-3 py-2 text-n-slate-12">{{ e.action_attempted }}</td>
            <td class="px-3 py-2 text-n-slate-11">{{ e.user_id || '—' }}</td>
            <td class="px-3 py-2 text-n-slate-11">{{ e.request_ip || '—' }}</td>
            <td class="px-3 py-2 text-n-slate-11 max-w-md">{{ e.details }}</td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>
