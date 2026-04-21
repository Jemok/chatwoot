<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';

const axios = window.axios;
const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

const enforced = ref(false);
const rules = ref([]);
const error = ref(null);
const saving = ref(false);

const refresh = async () => {
  error.value = null;
  try {
    const [acct, rulesRes] = await Promise.all([
      axios.get(`/api/v1/accounts/${accountId.value}`),
      axios.get(`/api/v1/accounts/${accountId.value}/automation_rules`),
    ]);
    enforced.value = !!acct.data.enforced_routing_enabled;
    rules.value = (rulesRes.data.payload || rulesRes.data || [])
      .filter(r => r.event_name === 'conversation_created')
      .map(r => ({ ...r, enforcedLocal: !!r.enforced }));
  } catch (e) {
    error.value = e.response?.data?.message || e.message;
  }
};

const toggleAccountFlag = async () => {
  saving.value = true;
  try {
    await axios.patch(`/api/v1/accounts/${accountId.value}`, {
      enforced_routing_enabled: enforced.value,
    });
  } catch (e) {
    error.value = e.message;
    enforced.value = !enforced.value; // revert
  } finally {
    saving.value = false;
  }
};

const toggleRule = async rule => {
  try {
    await axios.patch(
      `/api/v1/accounts/${accountId.value}/automation_rules/${rule.id}`,
      { enforced: rule.enforcedLocal }
    );
  } catch (e) {
    error.value = e.message;
    rule.enforcedLocal = !rule.enforcedLocal;
  }
};

onMounted(refresh);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6">
      <h1 class="text-2xl font-semibold text-n-slate-12">🔀 Routing Mode</h1>
      <p class="text-sm text-n-slate-11 mt-1">
        When enforced routing is on, marked rules run before round-robin and
        cannot be skipped by agents. The decision is recorded on every
        conversation as <code>route_reason</code>; supervisor overrides are
        audited under the <code>routing_override</code> policy.
      </p>
    </header>

    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>

    <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4 mb-6">
      <label class="flex items-center gap-3 cursor-pointer">
        <input
          v-model="enforced"
          type="checkbox"
          class="w-4 h-4"
          :disabled="saving"
          @change="toggleAccountFlag"
        />
        <span class="text-sm font-medium text-n-slate-12">
          Enforce routing for this account
        </span>
      </label>
      <p class="text-xs text-n-slate-10 mt-2">
        While off, all rules behave like the stock automation system
        (best-effort).
      </p>
    </section>

    <section
      class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden"
    >
      <div
        class="px-4 py-2 border-b border-n-weak text-sm font-medium text-n-slate-12"
      >
        conversation_created rules
      </div>
      <table class="w-full text-sm">
        <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
          <tr>
            <th class="text-left px-3 py-2">Rule</th>
            <th class="text-left px-3 py-2">Active</th>
            <th class="text-left px-3 py-2">Enforced</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in rules" :key="r.id" class="border-t border-n-weak">
            <td class="px-3 py-2 text-n-slate-12">{{ r.name }}</td>
            <td class="px-3 py-2 text-n-slate-11">
              {{ r.active ? 'yes' : 'no' }}
            </td>
            <td class="px-3 py-2">
              <input
                v-model="r.enforcedLocal"
                type="checkbox"
                class="w-4 h-4"
                @change="toggleRule(r)"
              />
            </td>
          </tr>
          <tr v-if="!rules.length">
            <td colspan="3" class="px-3 py-4 text-center text-n-slate-10">
              No conversation_created rules yet. Create one in Settings →
              Automation.
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>
