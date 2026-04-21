<script setup>
import { ref } from 'vue';
import InboxReconnectionRequired from '../../components/InboxReconnectionRequired.vue';

import linkedinClient from 'dashboard/api/channel/linkedinClient';

import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();

const isRequestingAuthorization = ref(false);

async function requestAuthorization() {
  try {
    isRequestingAuthorization.value = true;
    const response = await linkedinClient.generateAuthorization();

    const {
      data: { url },
    } = response;

    window.location.href = url;
  } catch (error) {
    useAlert(t('INBOX_MGMT.ADD.LINKEDIN.ERROR_AUTH'));
  } finally {
    isRequestingAuthorization.value = false;
  }
}
</script>

<template>
  <InboxReconnectionRequired class="mx-6" @reauthorize="requestAuthorization" />
</template>
