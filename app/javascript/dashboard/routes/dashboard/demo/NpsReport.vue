<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
const axios = window.axios;

const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

const data = ref(null);
const loading = ref(false);
const error = ref(null);
const days = ref(30);

const refresh = async () => {
  loading.value = true;
  error.value = null;
  try {
    const r = await axios.get(
      `/api/v1/accounts/${accountId.value}/nps_responses`,
      {
        params: { days: days.value, group_by: 'day', comments: 1 },
      }
    );
    data.value = r.data;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

const categoryColor = c => {
  if (c === 'promoter') return 'bg-emerald-100 text-emerald-800';
  if (c === 'passive') return 'bg-amber-100 text-amber-800';
  return 'bg-rose-100 text-rose-800';
};

onMounted(refresh);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">📊 NPS</h1>
        <p class="text-sm text-n-slate-11 mt-1">
          Net Promoter Score — promoters (9–10) minus detractors (0–6) over the
          rolling window.
        </p>
      </div>
      <div class="flex items-center gap-2">
        <select
          v-model.number="days"
          class="text-sm rounded border border-n-weak bg-n-solid-1 px-2 py-1"
          @change="refresh"
        >
          <option :value="7">Last 7 days</option>
          <option :value="30">Last 30 days</option>
          <option :value="90">Last 90 days</option>
        </select>
        <button
          type="button"
          class="px-3 py-1.5 rounded bg-n-solid-2 text-sm hover:bg-n-solid-3"
          :disabled="loading"
          @click="refresh"
        >
          Refresh
        </button>
      </div>
    </header>

    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>

    <section v-if="data" class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
      <div
        class="rounded-xl bg-n-solid-1 border-2 border-n-strong p-6 col-span-1"
      >
        <div class="text-xs uppercase tracking-wider text-n-slate-10">NPS</div>
        <div
          :class="[
            'text-5xl font-bold mt-2',
            data.nps >= 50
              ? 'text-emerald-700'
              : data.nps >= 0
                ? 'text-amber-700'
                : 'text-rose-700',
          ]"
        >
          {{ data.nps }}
        </div>
        <div class="text-xs text-n-slate-10 mt-1">
          {{ data.total }} responses · last {{ data.window_days }} d
        </div>
      </div>

      <div class="rounded-xl bg-emerald-50 border border-emerald-200 p-4">
        <div class="text-xs uppercase tracking-wider text-emerald-800">
          Promoters (9–10)
        </div>
        <div class="text-3xl font-semibold text-emerald-700 mt-1">
          {{ data.breakdown.promoters }}
        </div>
      </div>
      <div class="rounded-xl bg-amber-50 border border-amber-200 p-4">
        <div class="text-xs uppercase tracking-wider text-amber-800">
          Passives (7–8)
        </div>
        <div class="text-3xl font-semibold text-amber-700 mt-1">
          {{ data.breakdown.passives }}
        </div>
      </div>
      <div class="rounded-xl bg-rose-50 border border-rose-200 p-4">
        <div class="text-xs uppercase tracking-wider text-rose-800">
          Detractors (0–6)
        </div>
        <div class="text-3xl font-semibold text-rose-700 mt-1">
          {{ data.breakdown.detractors }}
        </div>
      </div>
    </section>

    <!-- Recent feed -->
    <section v-if="data?.trend?.length" class="mb-6">
      <h2 class="text-lg font-semibold text-n-slate-12 mb-3">
        Trend (daily NPS)
      </h2>
      <div
        class="rounded-lg border border-n-weak bg-n-solid-1 p-4 flex items-end gap-1 h-40 overflow-x-auto"
      >
        <div
          v-for="(t, i) in data.trend"
          :key="i"
          class="flex flex-col items-center min-w-[28px] gap-1"
          :title="`NPS ${t.nps} · ${t.total} resp · ${new Date(t.bucket).toLocaleDateString()}`"
        >
          <div
            class="w-6 rounded-t"
            :class="
              t.nps >= 50
                ? 'bg-emerald-500'
                : t.nps >= 0
                  ? 'bg-amber-500'
                  : 'bg-rose-500'
            "
            :style="{
              height: `${Math.max(4, Math.min(100, (t.nps + 100) / 2))}%`,
            }"
          />
          <div class="text-[9px] text-n-slate-10 whitespace-nowrap">
            {{
              new Date(t.bucket).toLocaleDateString(undefined, {
                month: 'short',
                day: 'numeric',
              })
            }}
          </div>
        </div>
      </div>
    </section>

    <section v-if="data?.comments?.length" class="mb-6">
      <h2 class="text-lg font-semibold text-n-slate-12 mb-3">
        Comments ({{ data.comments.length }})
        <span class="text-xs font-normal text-n-slate-10">admin-only</span>
      </h2>
      <div class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
            <tr>
              <th class="text-left px-3 py-2">When</th>
              <th class="text-left px-3 py-2">Score</th>
              <th class="text-left px-3 py-2">Comment</th>
              <th class="text-left px-3 py-2">Contact</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="r in data.comments"
              :key="r.id"
              class="border-t border-n-weak"
            >
              <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
                {{ r.created_at }}
              </td>
              <td class="px-3 py-2 text-n-slate-12 font-semibold">
                {{ r.score }}
              </td>
              <td class="px-3 py-2 text-n-slate-12">{{ r.comment }}</td>
              <td class="px-3 py-2 text-n-slate-11">#{{ r.contact_id }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section v-if="data?.recent?.length">
      <h2 class="text-lg font-semibold text-n-slate-12 mb-3">
        Recent responses
      </h2>
      <div class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
            <tr>
              <th class="text-left px-3 py-2">When</th>
              <th class="text-left px-3 py-2">Score</th>
              <th class="text-left px-3 py-2">Category</th>
              <th class="text-left px-3 py-2">Comment</th>
              <th class="text-left px-3 py-2">Contact</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="r in data.recent"
              :key="r.id"
              class="border-t border-n-weak"
            >
              <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
                {{ r.created_at }}
              </td>
              <td class="px-3 py-2 text-n-slate-12 font-semibold">
                {{ r.score }}
              </td>
              <td class="px-3 py-2">
                <span
                  :class="[
                    'text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wider',
                    categoryColor(r.category),
                  ]"
                >
                  {{ r.category }}
                </span>
              </td>
              <td class="px-3 py-2 text-n-slate-11">{{ r.comment || '—' }}</td>
              <td class="px-3 py-2 text-n-slate-11">#{{ r.contact_id }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>
