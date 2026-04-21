<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import appStoreClient from 'dashboard/api/channel/appStoreClient';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const router = useRouter();
const { accountId } = useAccount();

const inboxName = ref('');
const appId = ref('');
const issuerId = ref('');
const keyId = ref('');
const vendorName = ref('');
const p8Key = ref('');
const isSubmitting = ref(false);

const onFileChange = async event => {
  const file = event.target.files?.[0];
  if (!file) return;
  p8Key.value = await file.text();
};

const submit = async () => {
  if (!appId.value || !issuerId.value || !keyId.value || !p8Key.value) return;
  isSubmitting.value = true;
  try {
    const { data } = await appStoreClient.create({
      name: inboxName.value || vendorName.value || appId.value,
      app_id: appId.value,
      issuer_id: issuerId.value,
      key_id: keyId.value,
      vendor_name: vendorName.value,
      p8_private_key: p8Key.value,
    });
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: data.id, accountId: accountId.value },
    });
  } catch (e) {
    useAlert(t('INBOX_MGMT.ADD.APP_STORE.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div class="h-full p-6 w-full max-w-2xl flex-shrink-0 flex-grow-0 mx-auto">
    <h6 class="text-2xl font-medium mb-2">
      {{ $t('INBOX_MGMT.ADD.APP_STORE.TITLE') }}
    </h6>
    <p class="text-sm text-n-slate-11 mb-6">
      {{ $t('INBOX_MGMT.ADD.APP_STORE.HELP') }}
    </p>

    <form class="space-y-4" @submit.prevent="submit">
      <label class="block">
        <span class="text-sm font-medium">{{
          $t('INBOX_MGMT.ADD.APP_STORE.INBOX_NAME_LABEL')
        }}</span>
        <input
          v-model="inboxName"
          type="text"
          class="mt-1 block w-full rounded-md border border-n-weak px-3 py-2 bg-n-background text-n-slate-12"
        />
      </label>
      <label class="block">
        <span class="text-sm font-medium">{{
          $t('INBOX_MGMT.ADD.APP_STORE.APP_ID_LABEL')
        }}</span>
        <input
          v-model="appId"
          type="text"
          required
          class="mt-1 block w-full rounded-md border border-n-weak px-3 py-2 bg-n-background text-n-slate-12"
          placeholder="1234567890"
        />
      </label>
      <label class="block">
        <span class="text-sm font-medium">{{
          $t('INBOX_MGMT.ADD.APP_STORE.ISSUER_ID_LABEL')
        }}</span>
        <input
          v-model="issuerId"
          type="text"
          required
          class="mt-1 block w-full rounded-md border border-n-weak px-3 py-2 bg-n-background text-n-slate-12"
        />
      </label>
      <label class="block">
        <span class="text-sm font-medium">{{
          $t('INBOX_MGMT.ADD.APP_STORE.KEY_ID_LABEL')
        }}</span>
        <input
          v-model="keyId"
          type="text"
          required
          class="mt-1 block w-full rounded-md border border-n-weak px-3 py-2 bg-n-background text-n-slate-12"
        />
      </label>
      <label class="block">
        <span class="text-sm font-medium">{{
          $t('INBOX_MGMT.ADD.APP_STORE.VENDOR_NAME_LABEL')
        }}</span>
        <input
          v-model="vendorName"
          type="text"
          class="mt-1 block w-full rounded-md border border-n-weak px-3 py-2 bg-n-background text-n-slate-12"
        />
      </label>
      <label class="block">
        <span class="text-sm font-medium">{{
          $t('INBOX_MGMT.ADD.APP_STORE.P8_LABEL')
        }}</span>
        <input
          type="file"
          accept=".p8,application/x-x509-ca-cert,text/plain"
          class="mt-1 block w-full text-sm"
          @change="onFileChange"
        />
        <textarea
          v-model="p8Key"
          rows="6"
          class="mt-2 block w-full rounded-md border border-n-weak px-3 py-2 bg-n-background text-n-slate-12 font-mono text-xs"
          :placeholder="$t('INBOX_MGMT.ADD.APP_STORE.P8_PLACEHOLDER')"
        />
      </label>

      <button
        type="submit"
        :disabled="isSubmitting"
        class="px-5 py-2 rounded-full bg-n-brand text-white disabled:opacity-50"
      >
        {{ $t('INBOX_MGMT.ADD.APP_STORE.SUBMIT') }}
      </button>
    </form>
  </div>
</template>
