<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';

const axios = window.axios;
const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

const metrics = ref(null);
const loading = ref(false);
const error = ref(null);

const refresh = async () => {
  loading.value = true;
  error.value = null;
  try {
    const r = await axios.get(
      `/api/v1/accounts/${accountId.value}/csat_survey_responses/metrics`
    );
    metrics.value = r.data;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

onMounted(refresh);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          😊 CSAT (Banking)
        </h1>
        <p class="text-sm text-n-slate-11 mt-1">
          Customer satisfaction across all banking inboxes.
        </p>
      </div>
      <button
        type="button"
        class="px-3 py-1.5 rounded bg-n-solid-2 text-sm hover:bg-n-solid-3"
        :disabled="loading"
        @click="refresh"
      >
        {{ loading ? 'Loading…' : 'Refresh' }}
      </button>
    </header>
    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>
    <section v-if="metrics" class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div class="rounded-xl bg-n-solid-1 border-2 border-n-strong p-6">
        <div class="text-xs uppercase tracking-wider text-n-slate-10">
          CSAT %
        </div>
        <div class="text-5xl font-bold mt-2 text-emerald-700">
          {{
            metrics.total_response_count
              ? Math.round(
                  ((metrics.total_satisfaction_score || 0) /
                    metrics.total_response_count) *
                    20
                )
              : 0
          }}%
        </div>
        <div class="text-xs text-n-slate-10 mt-1">
          {{ metrics.total_response_count || 0 }} responses
        </div>
      </div>
      <div class="rounded-xl bg-n-solid-1 border border-n-weak p-4">
        <div class="text-xs uppercase tracking-wider text-n-slate-10">
          Sent surveys
        </div>
        <div class="text-3xl font-semibold text-n-slate-12 mt-1">
          {{ metrics.total_sent_message_count || 0 }}
        </div>
      </div>
      <div class="rounded-xl bg-n-solid-1 border border-n-weak p-4">
        <div class="text-xs uppercase tracking-wider text-n-slate-10">
          Response rate
        </div>
        <div class="text-3xl font-semibold text-n-slate-12 mt-1">
          {{ metrics.response_rate || 0 }}%
        </div>
      </div>
      <div class="rounded-xl bg-n-solid-1 border border-n-weak p-4">
        <div class="text-xs uppercase tracking-wider text-n-slate-10">
          Average rating
        </div>
        <div class="text-3xl font-semibold text-n-slate-12 mt-1">
          {{
            metrics.total_response_count
              ? (
                  (metrics.total_satisfaction_score || 0) /
                  metrics.total_response_count
                ).toFixed(2)
              : '—'
          }}
        </div>
      </div>
    </section>
  </div>
</template>
