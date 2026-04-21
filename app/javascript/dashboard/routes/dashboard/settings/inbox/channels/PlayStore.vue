<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import playStoreClient from 'dashboard/api/channel/playStoreClient';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const router = useRouter();
const { accountId } = useAccount();

const inboxName = ref('');
const packageName = ref('');
const credentialsJson = ref('');
const isSubmitting = ref(false);

const onFileChange = async event => {
  const file = event.target.files?.[0];
  if (!file) return;
  credentialsJson.value = await file.text();
};

const submit = async () => {
  if (!packageName.value || !credentialsJson.value) return;
  isSubmitting.value = true;
  try {
    const { data } = await playStoreClient.create({
      name: inboxName.value || packageName.value,
      package_name: packageName.value,
      credentials_json: credentialsJson.value,
    });
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: data.id, accountId: accountId.value },
    });
  } catch (e) {
    useAlert(t('INBOX_MGMT.ADD.PLAY_STORE.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div class="h-full p-6 w-full max-w-2xl flex-shrink-0 flex-grow-0 mx-auto">
    <h6 class="text-2xl font-medium mb-2">
      {{ $t('INBOX_MGMT.ADD.PLAY_STORE.TITLE') }}
    </h6>
    <p class="text-sm text-n-slate-11 mb-6">
      {{ $t('INBOX_MGMT.ADD.PLAY_STORE.HELP') }}
    </p>

    <form class="space-y-4" @submit.prevent="submit">
      <label class="block">
        <span class="text-sm font-medium">{{
          $t('INBOX_MGMT.ADD.PLAY_STORE.INBOX_NAME_LABEL')
        }}</span>
        <input
          v-model="inboxName"
          type="text"
          class="mt-1 block w-full rounded-md border border-n-weak px-3 py-2 bg-n-background text-n-slate-12"
          :placeholder="$t('INBOX_MGMT.ADD.PLAY_STORE.INBOX_NAME_PLACEHOLDER')"
        />
      </label>

      <label class="block">
        <span class="text-sm font-medium">{{
          $t('INBOX_MGMT.ADD.PLAY_STORE.PACKAGE_NAME_LABEL')
        }}</span>
        <input
          v-model="packageName"
          type="text"
          required
          class="mt-1 block w-full rounded-md border border-n-weak px-3 py-2 bg-n-background text-n-slate-12"
          placeholder="com.example.myapp"
        />
      </label>

      <label class="block">
        <span class="text-sm font-medium">{{
          $t('INBOX_MGMT.ADD.PLAY_STORE.CREDENTIALS_LABEL')
        }}</span>
        <input
          type="file"
          accept="application/json,.json"
          class="mt-1 block w-full text-sm"
          @change="onFileChange"
        />
        <textarea
          v-model="credentialsJson"
          rows="6"
          class="mt-2 block w-full rounded-md border border-n-weak px-3 py-2 bg-n-background text-n-slate-12 font-mono text-xs"
          :placeholder="$t('INBOX_MGMT.ADD.PLAY_STORE.CREDENTIALS_PLACEHOLDER')"
        />
      </label>

      <button
        type="submit"
        :disabled="isSubmitting || !packageName || !credentialsJson"
        class="px-5 py-2 rounded-full bg-n-brand text-white disabled:opacity-50"
      >
        {{ $t('INBOX_MGMT.ADD.PLAY_STORE.SUBMIT') }}
      </button>
    </form>
  </div>
</template>
