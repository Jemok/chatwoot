<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  isAccountSuspended,
  suspensionMessage,
} from 'dashboard/helper/suspensionState';
import Auth from 'dashboard/api/auth';

// Banking demo: full-screen overlay shown when the backend returns
// "Your account is suspended" on any account-scoped API call. Replaces the
// infinite loading spinner and offers a sign-out escape hatch.
const { t } = useI18n();
const message = computed(
  () => suspensionMessage.value || t('APP_GLOBAL.ACCOUNT_SUSPENDED.MESSAGE')
);

const signOut = () => Auth.logout();
</script>

<template>
  <div
    v-if="isAccountSuspended"
    class="fixed inset-0 z-[9999] flex items-center justify-center bg-n-background/95 backdrop-blur-sm p-6"
  >
    <div
      class="w-full max-w-md rounded-xl border border-n-weak bg-n-solid-1 shadow-xl p-8 text-center"
    >
      <div
        class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-n-amber-3 text-n-amber-11"
      >
        <fluent-icon icon="lock-closed" size="28" />
      </div>
      <h1 class="text-xl font-semibold text-n-slate-12 mb-2">
        {{ $t('APP_GLOBAL.ACCOUNT_SUSPENDED.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11 mb-6">
        {{ message }}
      </p>
      <button
        type="button"
        class="w-full inline-flex items-center justify-center rounded-md bg-n-brand px-4 py-2 text-sm font-medium text-white hover:bg-n-brand/90"
        @click="signOut"
      >
        {{ $t('APP_GLOBAL.ACCOUNT_SUSPENDED.LOGOUT') }}
      </button>
    </div>
  </div>
</template>
