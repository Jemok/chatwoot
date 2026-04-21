<script setup>
import { ref, computed, reactive, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { downloadCsv } from './csvExport';

const axios = window.axios;
const store = useStore();
const router = useRouter();
const { t } = useI18n();

const accountId = computed(() => store.getters.getCurrentAccountId);

const POLICIES = [
  { value: 'whatsapp_24h', label: 'AUDIT_TRAIL.POLICY.WHATSAPP_24H' },
  { value: 'facebook_7d', label: 'AUDIT_TRAIL.POLICY.FACEBOOK_7D' },
  { value: 'denied_action', label: 'AUDIT_TRAIL.POLICY.DENIED_ACTION' },
  { value: 'suspicious_login', label: 'AUDIT_TRAIL.POLICY.SUSPICIOUS_LOGIN' },
  { value: 'moderation_action', label: 'AUDIT_TRAIL.POLICY.MODERATION_ACTION' },
  { value: 'user_lifecycle', label: 'AUDIT_TRAIL.POLICY.USER_LIFECYCLE' },
  { value: 'profile_block', label: 'AUDIT_TRAIL.POLICY.PROFILE_BLOCK' },
  { value: 'routing_override', label: 'AUDIT_TRAIL.POLICY.ROUTING_OVERRIDE' },
];

const CHANNELS = [
  'Channel::Api',
  'Channel::WebWidget',
  'Channel::Email',
  'Channel::FacebookPage',
  'Channel::Instagram',
  'Channel::Whatsapp',
  'Channel::Sms',
  'Channel::TwitterProfile',
  'Channel::Line',
  'Channel::Telegram',
  'Channel::TwilioSms',
];

const PER_PAGE = 25;

const filters = reactive({
  policies: [],
  channelType: '',
  userId: '',
  from: '',
  to: '',
});

const items = ref([]);
const violations = ref([]);
const moderatedMeta = ref({ page: 1, per_page: PER_PAGE, total_count: 0 });
const violationsMeta = ref({ page: 1, per_page: PER_PAGE, total_count: 0 });
const moderatedPage = ref(1);
const violationsPage = ref(1);
const error = ref(null);
const loading = ref(false);
const expanded = ref({});

const buildParams = (page, { includePolicies }) => {
  const params = { page, per_page: PER_PAGE };
  if (includePolicies && filters.policies.length)
    params.policy = filters.policies;
  if (filters.channelType) params.channel_type = filters.channelType;
  if (filters.userId) params.user_id = filters.userId;
  if (filters.from) params.from = filters.from;
  if (filters.to) params.to = filters.to;
  return params;
};

const refresh = async () => {
  loading.value = true;
  error.value = null;
  try {
    const [moderated, vio] = await Promise.all([
      axios.get(`/api/v1/accounts/${accountId.value}/moderated_messages`, {
        params: buildParams(moderatedPage.value, { includePolicies: false }),
      }),
      axios.get(`/api/v1/accounts/${accountId.value}/policy_violation_logs`, {
        params: buildParams(violationsPage.value, { includePolicies: true }),
      }),
    ]);
    items.value = moderated.data?.data ?? [];
    moderatedMeta.value = moderated.data?.meta ?? moderatedMeta.value;
    violations.value = vio.data?.data ?? [];
    violationsMeta.value = vio.data?.meta ?? violationsMeta.value;
  } catch (e) {
    error.value =
      e.response?.data?.error || e.message || t('AUDIT_TRAIL.ERROR');
  } finally {
    loading.value = false;
  }
};

const togglePolicy = value => {
  const idx = filters.policies.indexOf(value);
  if (idx >= 0) filters.policies.splice(idx, 1);
  else filters.policies.push(value);
};

const clearFilters = () => {
  filters.policies = [];
  filters.channelType = '';
  filters.userId = '';
  filters.from = '';
  filters.to = '';
};

const totalPages = meta =>
  Math.max(1, Math.ceil((meta.total_count || 0) / (meta.per_page || PER_PAGE)));

const goModerated = delta => {
  const next = moderatedPage.value + delta;
  if (next < 1 || next > totalPages(moderatedMeta.value)) return;
  moderatedPage.value = next;
  refresh();
};

const goViolations = delta => {
  const next = violationsPage.value + delta;
  if (next < 1 || next > totalPages(violationsMeta.value)) return;
  violationsPage.value = next;
  refresh();
};

const openConversation = displayId => {
  if (!displayId) return;
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: displayId },
  });
};

const toggle = id => {
  expanded.value[id] = !expanded.value[id];
};

const exportModerated = () =>
  downloadCsv('moderated-messages', items.value, [
    'id',
    'conversation_display_id',
    'inbox_name',
    'inbox_channel_type',
    'deleted',
    'current_content',
    'original_content',
  ]);

const exportViolations = () =>
  downloadCsv('policy-violations', violations.value, [
    'id',
    'created_at',
    'policy',
    'action_attempted',
    'conversation_id',
    'conversation_display_id',
    'user_id',
    'request_ip',
    'details',
  ]);

let debounceTimer = null;
watch(
  filters,
  () => {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      moderatedPage.value = 1;
      violationsPage.value = 1;
      refresh();
    }, 300);
  },
  { deep: true }
);

onMounted(refresh);
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto bg-n-background p-8">
    <header class="mb-6 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          🛡️ {{ t('AUDIT_TRAIL.HEADER') }}
        </h1>
        <p class="text-sm text-n-slate-11 mt-1 max-w-3xl">
          {{ t('AUDIT_TRAIL.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex gap-2">
        <button
          type="button"
          class="px-3 py-1.5 rounded bg-n-solid-2 text-sm hover:bg-n-solid-3"
          :disabled="!items.length && !violations.length"
          @click="
            exportModerated();
            exportViolations();
          "
        >
          {{ t('AUDIT_TRAIL.EXPORT_CSV') }}
        </button>
        <button
          type="button"
          class="px-3 py-1.5 rounded bg-n-solid-2 text-sm hover:bg-n-solid-3"
          :disabled="loading"
          @click="refresh"
        >
          {{ loading ? t('AUDIT_TRAIL.LOADING') : t('AUDIT_TRAIL.REFRESH') }}
        </button>
      </div>
    </header>

    <div
      class="rounded-lg border border-n-weak bg-n-solid-1 p-4 mb-6 flex flex-col gap-3"
    >
      <div class="flex flex-wrap gap-2">
        <span
          class="text-xs font-semibold uppercase tracking-wider text-n-slate-10 self-center mr-2"
        >
          {{ t('AUDIT_TRAIL.FILTERS.POLICY') }}
        </span>
        <button
          v-for="p in POLICIES"
          :key="p.value"
          type="button"
          :class="[
            'px-2.5 py-1 rounded-full text-xs border transition',
            filters.policies.includes(p.value)
              ? 'bg-n-brand text-white border-n-brand'
              : 'bg-n-solid-2 text-n-slate-12 border-n-weak hover:bg-n-solid-3',
          ]"
          @click="togglePolicy(p.value)"
        >
          {{ t(p.label) }}
        </button>
      </div>

      <div class="flex flex-wrap gap-3 items-end">
        <label class="flex flex-col text-xs text-n-slate-10">
          {{ t('AUDIT_TRAIL.FILTERS.CHANNEL') }}
          <select
            v-model="filters.channelType"
            class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm text-n-slate-12"
          >
            <option value="">—</option>
            <option v-for="c in CHANNELS" :key="c" :value="c">
              {{ c.replace('Channel::', '') }}
            </option>
          </select>
        </label>
        <label class="flex flex-col text-xs text-n-slate-10">
          {{ t('AUDIT_TRAIL.FILTERS.USER_ID') }}
          <input
            v-model="filters.userId"
            type="number"
            min="1"
            :placeholder="t('AUDIT_TRAIL.FILTERS.PLACEHOLDER_USER')"
            class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 w-32"
          />
        </label>
        <label class="flex flex-col text-xs text-n-slate-10">
          {{ t('AUDIT_TRAIL.FILTERS.DATE_FROM') }}
          <input
            v-model="filters.from"
            type="date"
            class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm text-n-slate-12"
          />
        </label>
        <label class="flex flex-col text-xs text-n-slate-10">
          {{ t('AUDIT_TRAIL.FILTERS.DATE_TO') }}
          <input
            v-model="filters.to"
            type="date"
            class="mt-1 px-2 py-1 rounded border border-n-weak bg-n-solid-1 text-sm text-n-slate-12"
          />
        </label>
        <button
          type="button"
          class="px-3 py-1.5 rounded bg-n-solid-2 text-sm hover:bg-n-solid-3"
          @click="clearFilters"
        >
          {{ t('AUDIT_TRAIL.FILTERS.CLEAR') }}
        </button>
      </div>
    </div>

    <p v-if="error" class="text-sm text-rose-700 mb-4">{{ error }}</p>

    <section class="mb-8">
      <div class="flex items-center justify-between mb-3">
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('AUDIT_TRAIL.SECTIONS.MODERATED') }}
          <span class="text-xs font-normal text-n-slate-10"
            >({{ moderatedMeta.total_count }})</span
          >
        </h2>
        <div class="flex items-center gap-2 text-xs text-n-slate-11">
          <button
            type="button"
            class="px-2 py-1 rounded bg-n-solid-2 disabled:opacity-40"
            :disabled="moderatedPage <= 1"
            @click="goModerated(-1)"
          >
            {{ t('AUDIT_TRAIL.PAGINATION.PREV') }}
          </button>
          <span>{{
            t('AUDIT_TRAIL.PAGINATION.PAGE_OF', {
              page: moderatedPage,
              total: totalPages(moderatedMeta),
            })
          }}</span>
          <button
            type="button"
            class="px-2 py-1 rounded bg-n-solid-2 disabled:opacity-40"
            :disabled="moderatedPage >= totalPages(moderatedMeta)"
            @click="goModerated(1)"
          >
            {{ t('AUDIT_TRAIL.PAGINATION.NEXT') }}
          </button>
        </div>
      </div>
      <div v-if="!items.length" class="text-sm text-n-slate-10 italic">
        {{ t('AUDIT_TRAIL.EMPTY.MODERATED') }}
      </div>
      <div
        v-for="m in items"
        :key="m.id"
        class="rounded-lg border border-n-weak bg-n-solid-1 p-3 mb-2"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2 text-sm">
            <span
              :class="[
                'text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wider',
                m.deleted
                  ? 'bg-rose-100 text-rose-800'
                  : 'bg-amber-100 text-amber-800',
              ]"
            >
              {{ m.deleted ? 'Deleted' : 'Hidden' }}
            </span>
            <span class="text-n-slate-11">
              Conv #{{ m.conversation_display_id }} · {{ m.inbox_name }}
              <span
                v-if="m.inbox_channel_type"
                class="ml-1 text-[10px] uppercase tracking-wider text-n-slate-10"
              >
                {{ m.inbox_channel_type.replace('Channel::', '') }}
              </span>
            </span>
            <button
              v-if="m.conversation_display_id"
              type="button"
              class="text-xs text-n-brand hover:underline"
              @click="openConversation(m.conversation_display_id)"
            >
              {{ t('AUDIT_TRAIL.TABLE.VIEW') }}
            </button>
          </div>
          <button
            type="button"
            class="text-xs text-n-slate-11 hover:text-n-slate-12"
            @click="toggle(m.id)"
          >
            {{ expanded[m.id] ? 'Hide details' : 'Show original' }}
          </button>
        </div>
        <p class="text-sm text-n-slate-12 mt-2 italic line-through opacity-60">
          {{ m.current_content }}
        </p>
        <div v-if="expanded[m.id]" class="mt-2 p-2 rounded bg-n-solid-2">
          <div
            class="text-[10px] uppercase tracking-wider text-n-slate-10 mb-1"
          >
            Original content (preserved)
          </div>
          <p class="text-sm text-n-slate-12 whitespace-pre-wrap">
            {{ m.original_content || '(no original captured)' }}
          </p>
          <div v-if="m.moderation" class="text-[10px] text-n-slate-10 mt-2">
            By user #{{ m.moderation.by_user_id }} at {{ m.moderation.at }} ·
            simulated: {{ m.moderation.simulated }}
          </div>
        </div>
      </div>
    </section>

    <section>
      <div class="flex items-center justify-between mb-3">
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('AUDIT_TRAIL.SECTIONS.EVENTS') }}
          <span class="text-xs font-normal text-n-slate-10"
            >({{ violationsMeta.total_count }})</span
          >
        </h2>
        <div class="flex items-center gap-2 text-xs text-n-slate-11">
          <button
            type="button"
            class="px-2 py-1 rounded bg-n-solid-2 disabled:opacity-40"
            :disabled="violationsPage <= 1"
            @click="goViolations(-1)"
          >
            {{ t('AUDIT_TRAIL.PAGINATION.PREV') }}
          </button>
          <span>{{
            t('AUDIT_TRAIL.PAGINATION.PAGE_OF', {
              page: violationsPage,
              total: totalPages(violationsMeta),
            })
          }}</span>
          <button
            type="button"
            class="px-2 py-1 rounded bg-n-solid-2 disabled:opacity-40"
            :disabled="violationsPage >= totalPages(violationsMeta)"
            @click="goViolations(1)"
          >
            {{ t('AUDIT_TRAIL.PAGINATION.NEXT') }}
          </button>
        </div>
      </div>
      <div class="rounded-lg border border-n-weak bg-n-solid-1 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-n-solid-2 text-n-slate-10 text-xs uppercase">
            <tr>
              <th class="text-left px-3 py-2">
                {{ t('AUDIT_TRAIL.TABLE.WHEN') }}
              </th>
              <th class="text-left px-3 py-2">
                {{ t('AUDIT_TRAIL.TABLE.POLICY') }}
              </th>
              <th class="text-left px-3 py-2">
                {{ t('AUDIT_TRAIL.TABLE.ACTION') }}
              </th>
              <th class="text-left px-3 py-2">
                {{ t('AUDIT_TRAIL.TABLE.CHANNEL') }}
              </th>
              <th class="text-left px-3 py-2">
                {{ t('AUDIT_TRAIL.TABLE.CONVERSATION') }}
              </th>
              <th class="text-left px-3 py-2">
                {{ t('AUDIT_TRAIL.TABLE.USER') }}
              </th>
              <th class="text-left px-3 py-2">
                {{ t('AUDIT_TRAIL.TABLE.IP') }}
              </th>
              <th class="text-left px-3 py-2">
                {{ t('AUDIT_TRAIL.TABLE.DETAILS') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!violations.length">
              <td
                colspan="8"
                class="px-3 py-6 text-center text-n-slate-10 italic"
              >
                {{ t('AUDIT_TRAIL.EMPTY.EVENTS') }}
              </td>
            </tr>
            <tr
              v-for="v in violations"
              :key="v.id"
              class="border-t border-n-weak"
            >
              <td class="px-3 py-2 text-n-slate-11 whitespace-nowrap">
                {{ v.created_at }}
              </td>
              <td class="px-3 py-2">
                <span
                  class="inline-block px-2 py-0.5 rounded bg-rose-100 text-rose-800 text-xs"
                >
                  {{ v.policy }}
                </span>
              </td>
              <td class="px-3 py-2 text-n-slate-12">
                {{ v.action_attempted }}
              </td>
              <td class="px-3 py-2 text-n-slate-11">
                <span
                  v-if="v.inbox_channel_type"
                  class="text-[10px] uppercase tracking-wider"
                >
                  {{ v.inbox_channel_type.replace('Channel::', '') }}
                </span>
                <span v-else>—</span>
              </td>
              <td class="px-3 py-2 text-n-slate-11">
                <button
                  v-if="v.conversation_display_id"
                  type="button"
                  class="text-n-brand hover:underline"
                  @click="openConversation(v.conversation_display_id)"
                >
                  #{{ v.conversation_display_id }}
                </button>
                <span v-else>{{ v.conversation_id || '—' }}</span>
              </td>
              <td class="px-3 py-2 text-n-slate-11">{{ v.user_id || '—' }}</td>
              <td class="px-3 py-2 text-n-slate-11">
                {{ v.request_ip || '—' }}
              </td>
              <td class="px-3 py-2 text-n-slate-11 max-w-md">
                {{ v.details }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>
