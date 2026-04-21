<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import axios from 'axios';

const props = defineProps({
  contact: { type: Object, required: true },
});

const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);
const suggestions = ref([]);
const busyId = ref(null);
const error = ref(null);

const myPending = computed(() =>
  suggestions.value.filter(
    s =>
      s.status === 'pending' &&
      (s.primary_contact?.id === props.contact.id ||
        s.candidate_contact?.id === props.contact.id)
  )
);

const otherSide = s =>
  s.primary_contact?.id === props.contact.id
    ? s.candidate_contact
    : s.primary_contact;

const fetchSuggestions = async () => {
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${accountId.value}/identity_link_suggestions`
    );
    suggestions.value = data;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  }
};

const decide = async (s, action) => {
  busyId.value = s.id;
  error.value = null;
  try {
    await axios.post(
      `/api/v1/accounts/${accountId.value}/identity_link_suggestions/${s.id}/${action}`
    );
    await fetchSuggestions();
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    busyId.value = null;
  }
};

onMounted(fetchSuggestions);
watch(() => props.contact.id, fetchSuggestions);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div
    v-if="myPending.length"
    class="rounded-lg border border-violet-200 bg-violet-50 p-3 mt-2 mx-4"
  >
    <h4
      class="text-xs font-semibold uppercase tracking-wide text-violet-800 mb-2"
    >
      🔗 Identity Link Suggestion
    </h4>
    <div v-for="s in myPending" :key="s.id" class="text-sm space-y-2">
      <p class="text-violet-900">
        Same {{ s.match_key.replace('_', ' ') }}
        <span class="font-mono">{{ s.match_value }}</span> as
        <strong>{{ otherSide(s)?.name }}</strong>
        <span
          v-if="otherSide(s)?.channels?.length"
          class="text-xs text-violet-700"
        >
          ({{ otherSide(s).channels.join(', ') }})
        </span>
      </p>
      <div class="flex gap-2">
        <button
          type="button"
          class="text-xs px-2 py-1 rounded bg-violet-600 text-white hover:bg-violet-700 disabled:opacity-50"
          :disabled="busyId === s.id"
          @click="decide(s, 'approve')"
        >
          Merge profiles
        </button>
        <button
          type="button"
          class="text-xs px-2 py-1 rounded bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4 disabled:opacity-50"
          :disabled="busyId === s.id"
          @click="decide(s, 'dismiss')"
        >
          Dismiss
        </button>
      </div>
    </div>
    <p v-if="error" class="text-xs text-rose-600 mt-2">{{ error }}</p>
  </div>
</template>
