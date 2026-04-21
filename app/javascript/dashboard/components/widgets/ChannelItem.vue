<script setup>
import { computed } from 'vue';
import ChannelSelector from '../ChannelSelector.vue';

const props = defineProps({
  channel: {
    type: Object,
    required: true,
  },
  enabledFeatures: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['channelItemClick']);

const hasFbConfigured = computed(() => {
  return window.chatwootConfig?.fbAppId;
});

const hasInstagramConfigured = computed(() => {
  return window.chatwootConfig?.instagramAppId;
});

const hasTiktokConfigured = computed(() => {
  return window.chatwootConfig?.tiktokAppId;
});

const hasThreadsConfigured = computed(() => {
  return window.chatwootConfig?.threadsAppId;
});

const hasXConfigured = computed(() => {
  return window.chatwootConfig?.xAppId;
});

const hasLinkedinConfigured = computed(() => {
  return window.chatwootConfig?.linkedinAppId;
});

const hasYoutubeConfigured = computed(() => {
  return window.chatwootConfig?.youtubeAppId;
});

const isActive = computed(() => {
  const { key } = props.channel;
  if (Object.keys(props.enabledFeatures).length === 0) {
    return false;
  }
  if (key === 'website') {
    return props.enabledFeatures.channel_website;
  }
  if (key === 'facebook') {
    return props.enabledFeatures.channel_facebook && hasFbConfigured.value;
  }
  if (key === 'email') {
    return props.enabledFeatures.channel_email;
  }

  if (key === 'instagram') {
    return (
      props.enabledFeatures.channel_instagram && hasInstagramConfigured.value
    );
  }

  if (key === 'tiktok') {
    return props.enabledFeatures.channel_tiktok && hasTiktokConfigured.value;
  }

  if (key === 'threads') {
    return props.enabledFeatures.channel_threads && hasThreadsConfigured.value;
  }

  if (key === 'x') {
    return props.enabledFeatures.channel_x && hasXConfigured.value;
  }

  if (key === 'linkedin') {
    return (
      props.enabledFeatures.channel_linkedin && hasLinkedinConfigured.value
    );
  }

  if (key === 'youtube') {
    return props.enabledFeatures.channel_youtube && hasYoutubeConfigured.value;
  }

  if (key === 'play_store') {
    return props.enabledFeatures.channel_play_store_reviews;
  }

  if (key === 'app_store') {
    return props.enabledFeatures.channel_app_store_reviews;
  }

  if (key === 'voice') {
    return props.enabledFeatures.channel_voice;
  }

  return [
    'website',
    'twilio',
    'api',
    'whatsapp',
    'sms',
    'telegram',
    'line',
    'instagram',
    'tiktok',
    'threads',
    'x',
    'linkedin',
    'youtube',
    'play_store',
    'app_store',
    'voice',
  ].includes(key);
});

const isComingSoon = computed(() => {
  const { key } = props.channel;
  // Show "Coming Soon" only if the channel is marked as coming soon
  // and the corresponding feature flag is not enabled yet.
  return ['voice'].includes(key) && !isActive.value;
});

const onItemClick = () => {
  if (isActive.value) {
    emit('channelItemClick', props.channel.key);
  }
};
</script>

<template>
  <ChannelSelector
    :title="channel.title"
    :description="channel.description"
    :icon="channel.icon"
    :is-coming-soon="isComingSoon"
    :disabled="!isActive"
    @click="onItemClick"
  />
</template>
