<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';

const axios = window.axios;
const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

const agents = ref([]);
const onDuty = ref(null);
const error = ref(null);
const loading = ref(false);
const inviteForm = ref({ name: '', email: '', role: 'agent' });

const refresh = async () => {
  loading.value = true;
  error.value = null;
  try {
    const [a, d] = await Promise.all([
      axios.get(`/api/v1/accounts/${accountId.value}/agents`),
      axios.get(`/api/v1/accounts/${accountId.value}/shifts/on_duty`),
    ]);
    agents.value = a.data;
    onDuty.value = d.data;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

const lifecycleStatus = a => {
  // best-effort client-side derivation; truth is on the server
  if (!a.confirmed) return { label: 'Pending invite', tone: 'amber' };
  // account_user not exposed — we infer from availability
  if (a.suspended_at || a.account_user?.suspended_at)
    return { label: 'Suspended', tone: 'rose' };
  if (a.availability === 'offline') return { label: 'Offline', tone: 'slate' };
  return { label: 'Active', tone: 'emerald' };
};

const tones = {
  emerald: 'bg-emerald-100 text-emerald-800',
  rose: 'bg-rose-100 text-rose-800',
  amber: 'bg-amber-100 text-amber-800',
  slate: 'bg-n-slate-3 text-n-slate-11',
};

const invite = async () => {
  if (!inviteForm.value.email) return;
  error.value = null;
  try {
    await axios.post(`/api/v1/accounts/${accountId.value}/agents`, {
      agent: inviteForm.value,
    });
    inviteForm.value = { name: '', email: '', role: 'agent' };
    await refresh();
  } catch (e) {
    error.value =
      e.response?.data?.message || e.response?.data?.error || e.message;
  }
};

const suspend = async a => {
  const reason = window.prompt('Reason for suspension?');
  if (reason === null) return;
  try {
    await axios.post(
      `/api/v1/accounts/${accountId.value}/agents/${a.id}/suspend`,
      { reason }
    );
    await refresh();
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  }
};

const reinstate = async a => {
  if (!window.confirm(`Reinstate ${a.name}?`)) return;
  try {
    await axios.post(
      `/api/v1/accounts/${accountId.value}/agents/${a.id}/reinstate`
    );
    await refresh();
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  }
};

const disableUser = async a => {
  if (!window.confirm(`Permanently remove ${a.name} from this account?`))
    return;
  try {
    await axios.delete(`/api/v1/accounts/${accountId.value}/agents/${a.id}`);
    await refresh();
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  }
};

onMounted(refresh);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6">
      <h1 class="text-2xl font-semibold text-n-slate-12">
        👥 Users &amp; Lifecycle
      </h1>
      <p class="text-sm text-n-slate-11 mt-1">
        Create new agents, suspend or reinstate them, and remove them from the
        account. Suspended users can't sign in or send replies, even outside
        their shift.
      </p>
    </header>

    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>

    <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4 mb-6">
      <h2 class="text-sm font-semibold text-n-slate-12 mb-3">Invite agent</h2>
      <div class="grid grid-cols-1 md:grid-cols-4 gap-2">
        <input
          v-model="inviteForm.name"
          placeholder="Name"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        />
        <input
          v-model="inviteForm.email"
          type="email"
          placeholder="email@example.com"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        />
        <select
          v-model="inviteForm.role"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        >
          <option value="agent">Agent</option>
          <option value="administrator">Administrator</option>
        </select>
        <button
          type="button"
          class="px-3 py-1 rounded bg-emerald-600 text-white text-sm hover:bg-emerald-700"
          @click="invite"
        >
          Send invite
        </button>
      </div>
    </section>

    <section
      class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
          <tr>
            <th class="text-left px-3 py-2">Agent</th>
            <th class="text-left px-3 py-2">Email</th>
            <th class="text-left px-3 py-2">Role</th>
            <th class="text-left px-3 py-2">Availability</th>
            <th class="text-left px-3 py-2">Status</th>
            <th class="px-3 py-2" />
          </tr>
        </thead>
        <tbody>
          <tr v-for="a in agents" :key="a.id" class="border-t border-n-weak">
            <td class="px-3 py-2 text-n-slate-12">{{ a.name }}</td>
            <td class="px-3 py-2 text-n-slate-11">{{ a.email }}</td>
            <td class="px-3 py-2">
              <span
                class="text-[10px] px-1.5 py-0.5 rounded bg-n-slate-3 text-n-slate-11 uppercase tracking-wider"
              >
                {{ a.role }}
              </span>
            </td>
            <td class="px-3 py-2 text-n-slate-11">{{ a.availability }}</td>
            <td class="px-3 py-2">
              <span
                class="text-[11px] px-2 py-0.5 rounded font-medium"
                :class="tones[lifecycleStatus(a).tone]"
              >
                {{ lifecycleStatus(a).label }}
              </span>
            </td>
            <td class="px-3 py-2 text-right space-x-3">
              <button
                type="button"
                class="text-xs text-amber-700 hover:underline"
                @click="suspend(a)"
              >
                Suspend
              </button>
              <button
                type="button"
                class="text-xs text-emerald-700 hover:underline"
                @click="reinstate(a)"
              >
                Reinstate
              </button>
              <button
                type="button"
                class="text-xs text-rose-600 hover:underline"
                @click="disableUser(a)"
              >
                Remove
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </section>

    <p class="mt-4 text-xs text-n-slate-10">
      All suspend / reinstate / remove actions are written to the audit trail
      (policy: <code>user_lifecycle</code>).
    </p>
  </div>
</template>
