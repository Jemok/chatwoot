<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';

const axios = window.axios;
const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

const list = ref([]);
const loading = ref(false);
const error = ref(null);
const form = ref({
  channel_type: 'Channel::FacebookPage',
  platform_user_id: '',
  contact_id: '',
  reason: '',
  duration_hours: '',
});

const CHANNELS = [
  'Channel::FacebookPage',
  'Channel::TwitterProfile',
  'Channel::X',
  'Channel::Instagram',
];

const refresh = async () => {
  loading.value = true;
  error.value = null;
  try {
    const r = await axios.get(
      `/api/v1/accounts/${accountId.value}/blocked_profiles`
    );
    list.value = r.data || [];
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

const submit = async () => {
  error.value = null;
  try {
    await axios.post(`/api/v1/accounts/${accountId.value}/blocked_profiles`, {
      blocked_profile: {
        channel_type: form.value.channel_type,
        platform_user_id: form.value.platform_user_id,
        contact_id: form.value.contact_id || null,
        reason: form.value.reason,
      },
      duration_hours: form.value.duration_hours,
      reason: form.value.reason,
    });
    form.value = {
      channel_type: 'Channel::FacebookPage',
      platform_user_id: '',
      contact_id: '',
      reason: '',
      duration_hours: '',
    };
    await refresh();
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  }
};

const unblock = async id => {
  if (!window.confirm('Unblock this profile?')) return;
  await axios.delete(
    `/api/v1/accounts/${accountId.value}/blocked_profiles/${id}`
  );
  await refresh();
};

onMounted(refresh);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6">
      <h1 class="text-2xl font-semibold text-n-slate-12">
        🚫 Blocked Profiles
      </h1>
      <p class="text-sm text-n-slate-11 mt-1">
        Restrict Facebook / X / Instagram profiles from engaging with your
        pages. Platform block is simulated when scopes are unavailable; all
        future inbound content from blocked profiles is routed to the restricted
        log and audited.
      </p>
    </header>

    <section class="rounded-lg border border-n-weak bg-n-solid-1 p-4 mb-6">
      <h2 class="text-lg font-semibold text-n-slate-12 mb-3">Add a block</h2>
      <form
        class="grid grid-cols-2 md:grid-cols-3 gap-3"
        @submit.prevent="submit"
      >
        <label class="flex flex-col text-xs text-n-slate-10">
          Channel
          <select
            v-model="form.channel_type"
            class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm"
          >
            <option v-for="c in CHANNELS" :key="c" :value="c">
              {{ c.replace('Channel::', '') }}
            </option>
          </select>
        </label>
        <label class="flex flex-col text-xs text-n-slate-10">
          Platform user ID
          <input
            v-model="form.platform_user_id"
            required
            class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm"
          />
        </label>
        <label class="flex flex-col text-xs text-n-slate-10">
          Contact ID (optional)
          <input
            v-model="form.contact_id"
            type="number"
            class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm"
          />
        </label>
        <label class="flex flex-col text-xs text-n-slate-10 col-span-2">
          Reason
          <input
            v-model="form.reason"
            class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm"
          />
        </label>
        <label class="flex flex-col text-xs text-n-slate-10">
          Duration (hours, 0=permanent)
          <input
            v-model="form.duration_hours"
            type="number"
            min="0"
            class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm"
          />
        </label>
        <div class="col-span-full">
          <button
            type="submit"
            class="px-3 py-1.5 rounded bg-n-brand text-white text-sm"
          >
            Block profile
          </button>
        </div>
      </form>
      <p v-if="error" class="text-sm text-rose-700 mt-2">{{ error }}</p>
    </section>

    <section>
      <h2 class="text-lg font-semibold text-n-slate-12 mb-3">
        Blocked ({{ list.length }})
        <button
          type="button"
          class="ml-2 text-xs px-2 py-0.5 rounded bg-n-solid-2"
          @click="refresh"
        >
          Refresh
        </button>
      </h2>
      <div class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
            <tr>
              <th class="text-left px-3 py-2">Channel</th>
              <th class="text-left px-3 py-2">Platform User ID</th>
              <th class="text-left px-3 py-2">Contact</th>
              <th class="text-left px-3 py-2">Reason</th>
              <th class="text-left px-3 py-2">Blocked Until</th>
              <th class="text-left px-3 py-2">Active</th>
              <th class="text-left px-3 py-2" />
            </tr>
          </thead>
          <tbody>
            <tr v-if="!list.length">
              <td
                colspan="7"
                class="px-3 py-6 text-center italic text-n-slate-10"
              >
                No blocked profiles.
              </td>
            </tr>
            <tr v-for="b in list" :key="b.id" class="border-t border-n-weak">
              <td class="px-3 py-2">
                {{ (b.channel_type || '').replace('Channel::', '') }}
              </td>
              <td class="px-3 py-2 font-mono text-xs">
                {{ b.platform_user_id }}
              </td>
              <td class="px-3 py-2">{{ b.contact_id || '—' }}</td>
              <td class="px-3 py-2">{{ b.reason || '—' }}</td>
              <td class="px-3 py-2">
                {{
                  b.blocked_until
                    ? new Date(b.blocked_until).toLocaleString()
                    : 'Permanent'
                }}
              </td>
              <td class="px-3 py-2">
                <span
                  :class="b.active ? 'text-emerald-700' : 'text-n-slate-10'"
                  >{{ b.active ? 'Yes' : 'Expired' }}</span
                >
              </td>
              <td class="px-3 py-2">
                <button
                  type="button"
                  class="text-xs px-2 py-0.5 rounded bg-n-solid-2 hover:bg-n-solid-3"
                  @click="unblock(b.id)"
                >
                  Unblock
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>
