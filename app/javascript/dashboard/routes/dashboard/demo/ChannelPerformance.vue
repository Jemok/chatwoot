<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useStore } from 'vuex';
const axios = window.axios;

const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

const data = ref(null);
const loading = ref(false);
const error = ref(null);
let timer = null;

const refresh = async () => {
  loading.value = true;
  error.value = null;
  try {
    const r = await axios.get(
      `/api/v1/accounts/${accountId.value}/channel_performance`
    );
    data.value = r.data;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

const formatSec = s => {
  if (!s || s <= 0) return '—';
  if (s < 60) return `${s}s`;
  if (s < 3600) return `${Math.round(s / 60)}m`;
  return `${(s / 3600).toFixed(1)}h`;
};

const queueColor = k => {
  if (k === 'public') return 'bg-sky-100 text-sky-800';
  if (k === 'mentions') return 'bg-violet-100 text-violet-800';
  return 'bg-emerald-100 text-emerald-800';
};

onMounted(() => {
  refresh();
  timer = setInterval(refresh, 15000); // 15s auto-refresh
});
onBeforeUnmount(() => timer && clearInterval(timer));
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          📡 Channel Performance — Last 24 h
        </h1>
        <p class="text-sm text-n-slate-11 mt-1">
          Live snapshot per inbox. Auto-refreshes every 15 seconds.
        </p>
      </div>
      <button
        type="button"
        class="px-3 py-1.5 rounded bg-n-solid-2 text-sm hover:bg-n-solid-3"
        :disabled="loading"
        @click="refresh"
      >
        {{ loading ? 'Refreshing…' : 'Refresh' }}
      </button>
    </header>

    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>

    <section v-if="data" class="grid grid-cols-2 md:grid-cols-3 gap-4 mb-6">
      <div class="rounded-xl bg-n-solid-1 border border-n-weak p-4">
        <div class="text-xs uppercase text-n-slate-10 tracking-wider">Open</div>
        <div class="text-3xl font-semibold text-n-slate-12 mt-1">
          {{ data.totals.open }}
        </div>
      </div>
      <div class="rounded-xl bg-n-solid-1 border border-n-weak p-4">
        <div class="text-xs uppercase text-n-slate-10 tracking-wider">
          Resolved 24h
        </div>
        <div class="text-3xl font-semibold text-emerald-700 mt-1">
          {{ data.totals.resolved_24h }}
        </div>
      </div>
      <div class="rounded-xl bg-n-solid-1 border border-n-weak p-4">
        <div class="text-xs uppercase text-n-slate-10 tracking-wider">
          Pending &gt; 24h
        </div>
        <div class="text-3xl font-semibold text-rose-600 mt-1">
          {{ data.totals.pending_over_24h }}
        </div>
      </div>
    </section>

    <section
      v-if="data?.by_queue_kind"
      class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6"
    >
      <div
        v-for="(v, k) in data.by_queue_kind"
        :key="k"
        class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
      >
        <div class="flex items-center justify-between mb-2">
          <span
            :class="[
              'text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wider',
              queueColor(k),
            ]"
          >
            {{ k }} queue
          </span>
        </div>
        <div class="grid grid-cols-3 gap-2 text-center">
          <div>
            <div class="text-xs text-n-slate-10">Open</div>
            <div class="text-lg font-semibold text-n-slate-12">
              {{ v.open }}
            </div>
          </div>
          <div>
            <div class="text-xs text-n-slate-10">Resolved</div>
            <div class="text-lg font-semibold text-emerald-700">
              {{ v.resolved_24h }}
            </div>
          </div>
          <div>
            <div class="text-xs text-n-slate-10">&gt; 24h</div>
            <div class="text-lg font-semibold text-rose-600">
              {{ v.pending_over_24h }}
            </div>
          </div>
        </div>
      </div>
    </section>

    <section
      v-if="data"
      class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
          <tr>
            <th class="text-left px-3 py-2">Inbox</th>
            <th class="text-left px-3 py-2">Queue</th>
            <th class="text-right px-3 py-2">Open</th>
            <th class="text-right px-3 py-2">Resolved 24h</th>
            <th class="text-right px-3 py-2">Pending &gt; 24h</th>
            <th class="text-right px-3 py-2">Avg 1st Response</th>
            <th class="text-right px-3 py-2">Avg Resolution</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="r in data.by_inbox"
            :key="r.inbox_id"
            class="border-t border-n-weak"
          >
            <td class="px-3 py-2 text-n-slate-12">
              <div>{{ r.inbox_name }}</div>
              <div class="text-[10px] text-n-slate-10">
                {{ r.channel_type }}
              </div>
            </td>
            <td class="px-3 py-2">
              <span
                :class="[
                  'text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wider',
                  queueColor(r.queue_kind),
                ]"
              >
                {{ r.queue_kind || 'dm' }} · {{ r.source_type || '—' }}
              </span>
            </td>
            <td class="px-3 py-2 text-right text-n-slate-12">{{ r.open }}</td>
            <td class="px-3 py-2 text-right text-emerald-700">
              {{ r.resolved_24h }}
            </td>
            <td
              class="px-3 py-2 text-right"
              :class="
                r.pending_over_24h > 0
                  ? 'text-rose-600 font-semibold'
                  : 'text-n-slate-11'
              "
            >
              {{ r.pending_over_24h }}
            </td>
            <td class="px-3 py-2 text-right text-n-slate-11">
              {{ formatSec(r.avg_first_response_seconds) }}
            </td>
            <td class="px-3 py-2 text-right text-n-slate-11">
              {{ formatSec(r.avg_resolution_seconds) }}
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>
