<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
const axios = window.axios;

const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

const shifts = ref([]);
const onDuty = ref(null);
const agents = ref([]);
const error = ref(null);
const loading = ref(false);

const form = ref({
  user_id: null,
  starts_at: '',
  ends_at: '',
  status: 'scheduled',
});

const recurring = ref({
  user_id: null,
  weekdays: [1, 2, 3, 4, 5],
  start_time: '09:00',
  end_time: '17:00',
  weeks_ahead: 4,
});
const WEEKDAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const toggleWeekday = wd => {
  const i = recurring.value.weekdays.indexOf(wd);
  if (i >= 0) recurring.value.weekdays.splice(i, 1);
  else recurring.value.weekdays.push(wd);
};

const refresh = async () => {
  loading.value = true;
  try {
    const [s, d, a] = await Promise.all([
      axios.get(`/api/v1/accounts/${accountId.value}/shifts`),
      axios.get(`/api/v1/accounts/${accountId.value}/shifts/on_duty`),
      axios.get(`/api/v1/accounts/${accountId.value}/agents`),
    ]);
    shifts.value = s.data;
    onDuty.value = d.data;
    agents.value = a.data;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

const submitRecurring = async () => {
  if (!recurring.value.user_id || !recurring.value.weekdays.length) {
    error.value = 'Pick agent + at least one weekday';
    return;
  }
  error.value = null;
  try {
    const { data } = await axios.post(
      `/api/v1/accounts/${accountId.value}/shifts/bulk_create_recurring`,
      recurring.value
    );
    error.value = `Generated ${data.created} shifts.`;
    await refresh();
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  }
};

const submit = async () => {
  if (!form.value.user_id || !form.value.starts_at || !form.value.ends_at) {
    error.value = 'Pick agent + start + end';
    return;
  }
  error.value = null;
  try {
    await axios.post(`/api/v1/accounts/${accountId.value}/shifts`, form.value);
    form.value = {
      user_id: null,
      starts_at: '',
      ends_at: '',
      status: 'scheduled',
    };
    await refresh();
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  }
};

const remove = async id => {
  if (!confirm('Delete shift?')) return;
  await axios.delete(`/api/v1/accounts/${accountId.value}/shifts/${id}`);
  await refresh();
};

const startNow = duration => {
  if (!form.value.user_id) {
    error.value = 'Pick agent first';
    return;
  }
  // Phase 3 #5: produce a naive local-time string the way <input type="datetime-local"> expects.
  const toLocalInput = d => {
    const pad = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  };
  const now = new Date();
  const end = new Date(now.getTime() + duration * 3600 * 1000);
  form.value.starts_at = toLocalInput(now);
  form.value.ends_at = toLocalInput(end);
  form.value.status = 'active';
  submit();
};

onMounted(refresh);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6">
      <h1 class="text-2xl font-semibold text-n-slate-12">
        ⏰ Shifts &amp; On-duty controls
      </h1>
      <p class="text-sm text-n-slate-11 mt-1">
        Schedule agent shifts. When at least one shift exists in the account,
        off-shift agents are blocked from sending replies (administrators are
        exempt).
      </p>
      <p v-if="onDuty?.shift_timezone" class="text-xs text-n-slate-10 mt-1">
        All times shown in
        <span class="font-mono">{{ onDuty.shift_timezone }}</span>
      </p>
    </header>

    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>

    <section v-if="onDuty" class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      <div class="rounded-xl bg-n-solid-1 border border-n-weak p-4">
        <div class="text-xs uppercase text-n-slate-10 tracking-wider">
          Enforcement
        </div>
        <div
          class="text-2xl font-semibold mt-1"
          :class="[
            onDuty.enforcement_active ? 'text-emerald-700' : 'text-n-slate-10',
          ]"
        >
          {{ onDuty.enforcement_active ? 'Active' : 'Inactive' }}
        </div>
      </div>
      <div class="rounded-xl bg-n-solid-1 border border-n-weak p-4">
        <div class="text-xs uppercase text-n-slate-10 tracking-wider">
          Currently on shift
        </div>
        <div class="text-2xl font-semibold text-n-slate-12 mt-1">
          {{ onDuty.current_shift_count }}
        </div>
      </div>
      <div class="rounded-xl bg-n-solid-1 border border-n-weak p-4">
        <div class="text-xs uppercase text-n-slate-10 tracking-wider">
          My status
        </div>
        <div
          class="text-2xl font-semibold mt-1"
          :class="onDuty.on_duty ? 'text-emerald-700' : 'text-rose-700'"
        >
          {{ onDuty.on_duty ? 'On duty' : 'Off duty' }}
        </div>
      </div>
    </section>

    <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4 mb-6">
      <h2 class="text-sm font-semibold text-n-slate-12 mb-3">
        Recurring weekly schedule
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-6 gap-2 items-center">
        <select
          v-model.number="recurring.user_id"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        >
          <option :value="null">Pick agent…</option>
          <option v-for="a in agents" :key="a.id" :value="a.id">
            {{ a.name }}
          </option>
        </select>
        <div class="flex gap-1 md:col-span-2">
          <button
            v-for="(label, idx) in WEEKDAY_LABELS"
            :key="label"
            type="button"
            class="text-xs px-2 py-1 rounded border"
            :class="[
              recurring.weekdays.includes(idx)
                ? 'bg-emerald-600 text-white border-emerald-600'
                : 'bg-n-background text-n-slate-11 border-n-weak',
            ]"
            @click="toggleWeekday(idx)"
          >
            {{ label }}
          </button>
        </div>
        <input
          v-model="recurring.start_time"
          type="time"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        />
        <input
          v-model="recurring.end_time"
          type="time"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        />
        <div class="flex items-center gap-2">
          <input
            v-model.number="recurring.weeks_ahead"
            type="number"
            min="1"
            max="12"
            class="w-16 text-sm rounded border border-n-weak bg-n-background px-2 py-1"
          />
          <span class="text-xs text-n-slate-10">weeks</span>
        </div>
        <button
          type="button"
          class="md:col-span-6 px-3 py-1.5 rounded bg-indigo-600 text-white text-sm hover:bg-indigo-700"
          @click="submitRecurring"
        >
          Generate weekly shifts
        </button>
      </div>
    </section>

    <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4 mb-6">
      <h2 class="text-sm font-semibold text-n-slate-12 mb-3">
        Schedule a shift
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-5 gap-2">
        <select
          v-model.number="form.user_id"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        >
          <option :value="null">Pick agent…</option>
          <option v-for="a in agents" :key="a.id" :value="a.id">
            {{ a.name }} ({{ a.role }})
          </option>
        </select>
        <input
          v-model="form.starts_at"
          type="datetime-local"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        />
        <input
          v-model="form.ends_at"
          type="datetime-local"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        />
        <select
          v-model="form.status"
          class="text-sm rounded border border-n-weak bg-n-background px-2 py-1"
        >
          <option
            v-for="s in ['scheduled', 'active', 'completed', 'cancelled']"
            :key="s"
            :value="s"
          >
            {{ s }}
          </option>
        </select>
        <button
          type="button"
          class="px-3 py-1 rounded bg-emerald-600 text-white text-sm hover:bg-emerald-700"
          @click="submit"
        >
          Save
        </button>
      </div>
      <div class="flex gap-2 mt-3 text-xs text-n-slate-10">
        Quick: start agent on shift now for
        <button class="underline" @click="startNow(1)">1h</button>
        <button class="underline" @click="startNow(4)">4h</button>
        <button class="underline" @click="startNow(8)">8h</button>
      </div>
    </section>

    <section
      class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
          <tr>
            <th class="text-left px-3 py-2">Agent</th>
            <th class="text-left px-3 py-2">Starts</th>
            <th class="text-left px-3 py-2">Ends</th>
            <th class="text-left px-3 py-2">Status</th>
            <th class="text-left px-3 py-2">Now</th>
            <th class="px-3 py-2" />
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in shifts" :key="s.id" class="border-t border-n-weak">
            <td class="px-3 py-2 text-n-slate-12">
              {{ s.user_name || `User #${s.user_id}` }}
            </td>
            <td class="px-3 py-2 text-n-slate-11">
              {{ s.starts_at_local || s.starts_at }}
            </td>
            <td class="px-3 py-2 text-n-slate-11">
              {{ s.ends_at_local || s.ends_at }}
            </td>
            <td class="px-3 py-2">
              <span
                class="text-[10px] px-1.5 py-0.5 rounded bg-n-slate-3 text-n-slate-11 uppercase tracking-wider"
              >
                {{ s.status }}
              </span>
            </td>
            <td class="px-3 py-2">
              <span
                v-if="s.is_current"
                class="text-emerald-700 font-semibold text-xs"
              >
                ● live
              </span>
              <span v-else class="text-n-slate-10 text-xs">—</span>
            </td>
            <td class="px-3 py-2 text-right">
              <button
                type="button"
                class="text-xs text-rose-600 hover:underline"
                @click="remove(s.id)"
              >
                Delete
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>
