<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import axios from 'axios';
import { useAdmin } from 'dashboard/composables/useAdmin';

const props = defineProps({
  contact: { type: Object, required: true },
});

const store = useStore();
const { isAdmin } = useAdmin();
const accountId = computed(() => store.getters.getCurrentAccountId);

const banking = computed(() => props.contact.banking || {});
const hasBanking = computed(() => Object.keys(banking.value).length > 0);

const revealed = ref(null);
const revealing = ref(false);
const revealError = ref(null);

const reveal = async () => {
  if (revealed.value) {
    revealed.value = null;
    return;
  }
  revealing.value = true;
  revealError.value = null;
  try {
    const { data } = await axios.post(
      `/api/v1/accounts/${accountId.value}/contacts/${props.contact.id}/reveal_account_number`
    );
    revealed.value = data.account_number;
  } catch (e) {
    revealError.value = e.response?.data?.error || e.message;
  } finally {
    revealing.value = false;
  }
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div
    v-if="hasBanking"
    class="rounded-lg border border-n-weak bg-n-solid-1 p-3 mt-2 mx-4"
  >
    <div class="flex items-center justify-between mb-2">
      <h4 class="text-xs font-semibold uppercase tracking-wide text-n-slate-10">
        🏦 Banking Profile
      </h4>
      <span
        v-if="banking.segment"
        class="text-[10px] px-1.5 py-0.5 rounded bg-violet-100 text-violet-800 uppercase tracking-wider"
      >
        {{ banking.segment }}
      </span>
    </div>
    <div class="space-y-1.5 text-sm">
      <div v-if="banking.cif" class="flex justify-between">
        <span class="text-n-slate-10">CIF</span>
        <span class="font-mono text-n-slate-12">{{ banking.cif }}</span>
      </div>
      <div
        v-if="banking.masked_account_number"
        class="flex justify-between items-center"
      >
        <span class="text-n-slate-10">Account</span>
        <div class="flex items-center gap-2">
          <span class="font-mono text-n-slate-12">
            {{ revealed || banking.masked_account_number }}
          </span>
          <button
            v-if="isAdmin"
            type="button"
            class="text-[10px] px-1.5 py-0.5 rounded bg-n-slate-3 hover:bg-n-slate-4 text-n-slate-11"
            :disabled="revealing"
            @click="reveal"
          >
            {{ revealed ? 'Hide' : revealing ? '...' : 'Reveal' }}
          </button>
        </div>
      </div>
      <div v-if="banking.branch" class="flex justify-between">
        <span class="text-n-slate-10">Branch</span>
        <span class="text-n-slate-12">{{ banking.branch }}</span>
      </div>
      <div v-if="banking.kyc_level" class="flex justify-between">
        <span class="text-n-slate-10">KYC</span>
        <span class="text-n-slate-12">{{ banking.kyc_level }}</span>
      </div>
    </div>
    <p v-if="revealError" class="text-xs text-rose-600 mt-2">
      {{ revealError }}
    </p>
    <p v-if="revealed" class="text-[10px] text-amber-700 mt-2">
      ⚠️ Reveal logged for audit (admin action).
    </p>
  </div>
</template>
