<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
const axios = window.axios;

const store = useStore();
const router = useRouter();
const accountId = computed(() => store.getters.getCurrentAccountId);
const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);

const filters = ref({
  status: 'open',
  queue_kind: '',
  source_type: '',
  inbox_id: '',
  assignee_type: 'all',
  sort_by: 'last_activity_at_desc',
});

const conversations = ref([]);
const meta = ref(null);
const error = ref(null);
const loading = ref(false);

const refresh = async () => {
  loading.value = true;
  error.value = null;
  try {
    const params = Object.fromEntries(
      Object.entries(filters.value).filter(([, v]) => v !== '' && v !== null)
    );
    const r = await axios.get(
      `/api/v1/accounts/${accountId.value}/conversations`,
      { params }
    );
    conversations.value = r.data?.data?.payload || [];
    meta.value = r.data?.data?.meta || null;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

const reset = () => {
  filters.value = {
    status: 'open',
    queue_kind: '',
    source_type: '',
    inbox_id: '',
    assignee_type: 'all',
    sort_by: 'last_activity_at_desc',
  };
};

const channelLabel = ct => (ct || '').replace('Channel::', '');

const openConv = c => {
  router.push(`/app/accounts/${accountId.value}/conversations/${c.id}`);
};

watch(filters, refresh, { deep: true });
onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
  refresh();
});
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-4">
      <h1 class="text-2xl font-semibold text-n-slate-12">🔍 Filtered Inbox</h1>
      <p class="text-sm text-n-slate-11 mt-1">
        Presenter-friendly filters across queue, source, status, inbox, sort.
        Live results via the standard conversations API.
      </p>
    </header>

    <!-- Filter toolbar -->
    <section
      class="rounded-xl border border-n-weak bg-n-solid-1 p-3 mb-4 flex flex-wrap items-center gap-2"
    >
      <select
        v-model="filters.status"
        class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
      >
        <option value="open">Open</option>
        <option value="resolved">Resolved</option>
        <option value="pending">Pending</option>
        <option value="snoozed">Snoozed</option>
        <option value="all">All statuses</option>
      </select>
      <select
        v-model="filters.queue_kind"
        class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
      >
        <option value="">All queues</option>
        <option value="dm">DM queue</option>
        <option value="public">Public queue</option>
        <option value="mentions">Mentions queue</option>
      </select>
      <select
        v-model="filters.source_type"
        class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
      >
        <option value="">All source types</option>
        <option value="dm">DM</option>
        <option value="comments">Comments</option>
        <option value="wall_posts">Wall posts</option>
        <option value="mentions">Mentions</option>
      </select>
      <select
        v-model.number="filters.inbox_id"
        class="text-sm rounded border border-n-weak bg-n-background px-2 py-1 max-w-[16rem]"
      >
        <option value="">All inboxes</option>
        <option v-for="i in inboxes" :key="i.id" :value="i.id">
          {{ i.name }} ({{ channelLabel(i.channel_type) }})
        </option>
      </select>
      <select
        v-model="filters.assignee_type"
        class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
      >
        <option value="all">All assignees</option>
        <option value="me">Mine</option>
        <option value="unassigned">Unassigned</option>
        <option value="assigned">Assigned</option>
      </select>
      <select
        v-model="filters.sort_by"
        class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
      >
        <option value="last_activity_at_desc">Latest activity ↓</option>
        <option value="last_activity_at_asc">Latest activity ↑</option>
        <option value="created_at_desc">Newest first</option>
        <option value="created_at_asc">Oldest first</option>
        <option value="waiting_since_desc">Longest waiting first</option>
      </select>
      <button
        type="button"
        class="text-xs underline text-n-slate-11"
        @click="reset"
      >
        Reset
      </button>
      <span class="ml-auto text-xs text-n-slate-10">
        {{
          loading
            ? 'Loading…'
            : `${conversations.length} of ${meta?.all_count || 0}`
        }}
      </span>
    </section>

    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>

    <section
      class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
          <tr>
            <th class="text-left px-3 py-2">#</th>
            <th class="text-left px-3 py-2">Contact</th>
            <th class="text-left px-3 py-2">Inbox</th>
            <th class="text-left px-3 py-2">Queue · Source</th>
            <th class="text-left px-3 py-2">Status</th>
            <th class="text-left px-3 py-2">Assignee</th>
            <th class="text-left px-3 py-2">Last activity</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!conversations.length && !loading">
            <td colspan="7" class="px-3 py-6 text-center text-n-slate-10">
              No conversations match the current filters.
            </td>
          </tr>
          <tr
            v-for="c in conversations"
            :key="c.id"
            class="border-t border-n-weak hover:bg-n-solid-2 cursor-pointer"
            @click="openConv(c)"
          >
            <td class="px-3 py-2 text-n-slate-12 font-mono">#{{ c.id }}</td>
            <td class="px-3 py-2 text-n-slate-12">
              {{ c.meta?.sender?.name || '—' }}
            </td>
            <td class="px-3 py-2 text-n-slate-11">
              {{ c.inbox_id }} · {{ channelLabel(c.meta?.channel) }}
            </td>
            <td class="px-3 py-2 text-n-slate-11">
              <span
                class="text-[10px] px-1.5 py-0.5 rounded bg-violet-100 text-violet-800 uppercase tracking-wider mr-1"
              >
                {{ c.queue_kind || '—' }}
              </span>
              <span
                class="text-[10px] px-1.5 py-0.5 rounded bg-sky-100 text-sky-800 uppercase tracking-wider"
              >
                {{ c.source_type || '—' }}
              </span>
            </td>
            <td class="px-3 py-2">
              <span
                :class="[
                  'text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wider',
                  c.status === 'resolved'
                    ? 'bg-emerald-100 text-emerald-800'
                    : 'bg-amber-100 text-amber-800',
                ]"
              >
                {{ c.status }}
              </span>
            </td>
            <td class="px-3 py-2 text-n-slate-11">
              {{ c.meta?.assignee?.name || '—' }}
            </td>
            <td class="px-3 py-2 text-n-slate-11">
              {{
                c.last_activity_at
                  ? new Date(c.last_activity_at * 1000).toLocaleString()
                  : '—'
              }}
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>
