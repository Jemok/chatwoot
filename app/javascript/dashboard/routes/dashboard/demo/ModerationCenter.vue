<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';

const axios = window.axios;
const store = useStore();
const router = useRouter();
const accountId = computed(() => store.getters.getCurrentAccountId);

const rows = ref([]);
const meta = ref({ page: 1, per_page: 25, total_count: 0 });
const page = ref(1);
const loading = ref(false);
const error = ref(null);
const selected = ref(new Set());
const filters = ref({ channel_type: '', status: 'open' });
const reasonDialog = ref({ open: false, action: '', messageIds: [] });
const reasonText = ref('');

const CHANNELS = [
  'Channel::FacebookPage',
  'Channel::Instagram',
  'Channel::Tiktok',
  'Channel::X',
  'Channel::Threads',
];

const fetchRows = async () => {
  loading.value = true;
  error.value = null;
  try {
    const r = await axios.get(
      `/api/v1/accounts/${accountId.value}/public_comments`,
      {
        params: {
          page: page.value,
          per_page: 25,
          channel_type: filters.value.channel_type || undefined,
          status: filters.value.status || undefined,
        },
      }
    );
    rows.value = r.data?.data ?? [];
    meta.value = r.data?.meta ?? meta.value;
    selected.value = new Set();
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

const toggleRow = id => {
  if (selected.value.has(id)) selected.value.delete(id);
  else selected.value.add(id);
  selected.value = new Set(selected.value);
};

const selectAll = () => {
  if (selected.value.size === rows.value.length) {
    selected.value = new Set();
  } else {
    selected.value = new Set(rows.value.map(r => r.id));
  }
};

const openReason = action => {
  if (!selected.value.size) return;
  reasonDialog.value = { open: true, action, messageIds: [...selected.value] };
  reasonText.value = '';
};

const postModerate = (conversationId, messageId, action, reason) =>
  axios.post(
    `/api/v1/accounts/${accountId.value}/conversations/${conversationId}/messages/${messageId}/moderate`,
    { action_type: action, reason }
  );

const moderateRow = async (row, action) => {
  const reason = window.prompt(`Reason for ${action}?`, '');
  if (reason === null) return;
  await postModerate(row.conversation_id, row.id, action, reason);
  await fetchRows();
};

const confirmBulk = async () => {
  const { action, messageIds } = reasonDialog.value;
  reasonDialog.value.open = false;
  loading.value = true;
  try {
    await Promise.all(
      messageIds.map(id => {
        const row = rows.value.find(r => r.id === id);
        return (
          row &&
          postModerate(row.conversation_id, row.id, action, reasonText.value)
        );
      })
    );
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  }
  await fetchRows();
};

const openConversation = displayId =>
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: displayId },
  });

const go = delta => {
  const total = Math.max(
    1,
    Math.ceil((meta.value.total_count || 0) / (meta.value.per_page || 25))
  );
  const next = page.value + delta;
  if (next < 1 || next > total) return;
  page.value = next;
  fetchRows();
};

onMounted(fetchRows);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          🛡️ Moderation Center
        </h1>
        <p class="text-sm text-n-slate-11 mt-1">
          Cross-channel public comments (FB / IG / TikTok / X / Threads). Hide
          or delete offensive content; original text is preserved in the audit
          trail.
        </p>
      </div>
      <button
        type="button"
        class="px-3 py-1.5 rounded bg-n-solid-2 text-sm hover:bg-n-solid-3"
        :disabled="loading"
        @click="fetchRows"
      >
        {{ loading ? 'Loading…' : 'Refresh' }}
      </button>
    </header>

    <div
      class="rounded-lg border border-n-weak bg-n-solid-1 p-4 mb-4 flex flex-wrap items-end gap-3"
    >
      <label class="flex flex-col text-xs text-n-slate-10">
        Channel
        <select
          v-model="filters.channel_type"
          class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm"
          @change="fetchRows"
        >
          <option value="">—</option>
          <option v-for="c in CHANNELS" :key="c" :value="c">
            {{ c.replace('Channel::', '') }}
          </option>
        </select>
      </label>
      <label class="flex flex-col text-xs text-n-slate-10">
        Status
        <select
          v-model="filters.status"
          class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm"
          @change="fetchRows"
        >
          <option value="">All</option>
          <option value="open">Open</option>
          <option value="moderated">Moderated</option>
        </select>
      </label>
      <div class="flex gap-2 ml-auto">
        <button
          type="button"
          :disabled="!selected.size"
          class="px-3 py-1.5 rounded bg-amber-100 text-amber-900 text-sm disabled:opacity-40"
          @click="openReason('hide')"
        >
          Hide selected ({{ selected.size }})
        </button>
        <button
          type="button"
          :disabled="!selected.size"
          class="px-3 py-1.5 rounded bg-rose-100 text-rose-900 text-sm disabled:opacity-40"
          @click="openReason('delete')"
        >
          Delete selected
        </button>
      </div>
    </div>

    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>

    <div class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
          <tr>
            <th class="px-3 py-2 w-8">
              <input
                type="checkbox"
                :checked="selected.size === rows.length && rows.length > 0"
                @change="selectAll"
              />
            </th>
            <th class="text-left px-3 py-2">Channel</th>
            <th class="text-left px-3 py-2">Conversation</th>
            <th class="text-left px-3 py-2">Content</th>
            <th class="text-left px-3 py-2">Status</th>
            <th class="text-left px-3 py-2">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!rows.length">
            <td
              colspan="6"
              class="px-3 py-8 text-center text-n-slate-10 italic"
            >
              No public comments match the current filters.
            </td>
          </tr>
          <tr v-for="r in rows" :key="r.id" class="border-t border-n-weak">
            <td class="px-3 py-2">
              <input
                type="checkbox"
                :checked="selected.has(r.id)"
                @change="toggleRow(r.id)"
              />
            </td>
            <td class="px-3 py-2">
              <span
                class="text-[10px] uppercase tracking-wider px-1.5 py-0.5 rounded bg-n-solid-2"
              >
                {{ (r.channel_type || '').replace('Channel::', '') }}
              </span>
            </td>
            <td class="px-3 py-2">
              <button
                type="button"
                class="text-n-brand hover:underline text-xs"
                @click="openConversation(r.conversation_display_id)"
              >
                #{{ r.conversation_display_id }}
              </button>
            </td>
            <td class="px-3 py-2 max-w-md">
              <p
                class="text-n-slate-12"
                :class="{ 'line-through opacity-60': r.moderated }"
              >
                {{ r.content }}
              </p>
              <p
                v-if="r.moderated && r.original_content"
                class="text-[10px] text-n-slate-10 italic mt-1"
              >
                Original: {{ r.original_content }}
              </p>
            </td>
            <td class="px-3 py-2">
              <span
                v-if="r.moderated"
                class="text-[10px] uppercase px-1.5 py-0.5 rounded bg-amber-100 text-amber-800"
              >
                {{ r.moderation?.action || 'moderated' }}
                <span v-if="r.moderation?.simulated" class="ml-1">(sim)</span>
              </span>
              <span
                v-else
                class="text-[10px] uppercase px-1.5 py-0.5 rounded bg-emerald-100 text-emerald-800"
                >Open</span
              >
            </td>
            <td class="px-3 py-2">
              <div class="flex gap-1">
                <button
                  v-if="!r.moderated"
                  type="button"
                  class="text-xs px-2 py-0.5 rounded bg-amber-100 text-amber-900"
                  @click="moderateRow(r, 'hide')"
                >
                  Hide
                </button>
                <button
                  v-if="r.moderated && r.moderation?.action !== 'delete'"
                  type="button"
                  class="text-xs px-2 py-0.5 rounded bg-emerald-100 text-emerald-900"
                  @click="moderateRow(r, 'unhide')"
                >
                  Unhide
                </button>
                <button
                  type="button"
                  class="text-xs px-2 py-0.5 rounded bg-rose-100 text-rose-900"
                  @click="moderateRow(r, 'delete')"
                >
                  Delete
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="flex items-center gap-2 mt-4 text-xs text-n-slate-11">
      <button
        type="button"
        class="px-2 py-1 rounded bg-n-solid-2 disabled:opacity-40"
        :disabled="page <= 1"
        @click="go(-1)"
      >
        Prev
      </button>
      <span
        >Page {{ page }} /
        {{
          Math.max(
            1,
            Math.ceil((meta.total_count || 0) / (meta.per_page || 25))
          )
        }}
        · {{ meta.total_count }} total</span
      >
      <button
        type="button"
        class="px-2 py-1 rounded bg-n-solid-2 disabled:opacity-40"
        :disabled="
          page >= Math.ceil((meta.total_count || 0) / (meta.per_page || 25))
        "
        @click="go(1)"
      >
        Next
      </button>
    </div>

    <div
      v-if="reasonDialog.open"
      class="fixed inset-0 bg-black/40 flex items-center justify-center z-50"
    >
      <div class="bg-n-background rounded-lg p-5 w-96 shadow-xl">
        <h3 class="text-lg font-semibold text-n-slate-12 mb-3">
          {{ reasonDialog.action === 'hide' ? 'Hide' : 'Delete' }}
          {{ reasonDialog.messageIds.length }} message(s)
        </h3>
        <label class="block text-xs text-n-slate-10 mb-1"
          >Reason (captured in audit trail)</label
        >
        <textarea
          v-model="reasonText"
          rows="3"
          class="w-full px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm"
        />
        <div class="flex justify-end gap-2 mt-3">
          <button
            type="button"
            class="px-3 py-1.5 rounded bg-n-solid-2 text-sm"
            @click="reasonDialog.open = false"
          >
            Cancel
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded bg-n-brand text-white text-sm"
            @click="confirmBulk"
          >
            Confirm
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
