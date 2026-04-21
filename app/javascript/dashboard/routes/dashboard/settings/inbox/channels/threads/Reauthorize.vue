<script setup>
import { ref } from 'vue';
import InboxReconnectionRequired from '../../components/InboxReconnectionRequired.vue';

import threadsClient from 'dashboard/api/channel/threadsClient';

import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();

const isRequestingAuthorization = ref(false);

async function requestAuthorization() {
  try {
    isRequestingAuthorization.value = true;
    const response = await threadsClient.generateAuthorization();

    const {
      data: { url },
    } = response;

    window.location.href = url;
  } catch (error) {
    useAlert(t('INBOX_MGMT.ADD.THREADS.ERROR_AUTH'));
  } finally {
    isRequestingAuthorization.value = false;
  }
}
</script>

<template>
  <InboxReconnectionRequired class="mx-6" @reauthorize="requestAuthorization" />
</template>
