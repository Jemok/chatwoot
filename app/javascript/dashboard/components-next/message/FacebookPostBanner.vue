<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  additionalAttributes: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

const feedType = computed(() => props.additionalAttributes?.type);
const isFacebookFeed = computed(() => feedType.value === 'facebook_feed');
const isInstagramFeed = computed(() => feedType.value === 'instagram_feed');
const isThreadsFeed = computed(() => feedType.value === 'threads_feed');
const isSupportedFeed = computed(
  () => isFacebookFeed.value || isInstagramFeed.value || isThreadsFeed.value
);
const postContent = computed(() => props.additionalAttributes?.post_content);
const mediaUrl = computed(() => props.additionalAttributes?.media_url);
const postType = computed(() => props.additionalAttributes?.post_type);
const isAd = computed(() => props.additionalAttributes?.is_ad);
const isMention = computed(() => props.additionalAttributes?.is_mention);
const isQuote = computed(() => props.additionalAttributes?.is_quote);
const isVisitorPost = computed(
  () => props.additionalAttributes?.is_visitor_post
);
const permalinkUrl = computed(() => props.additionalAttributes?.permalink_url);
const isVideo = computed(() => postType.value === 'video');
const hasAnyContent = computed(
  () => postContent.value || mediaUrl.value || permalinkUrl.value
);
const iconClass = computed(() => {
  if (isThreadsFeed.value) return 'i-ri-threads-line text-n-slate-12 text-base';
  if (isInstagramFeed.value)
    return 'i-ri-instagram-line text-pink-500 text-base';
  return 'i-ri-facebook-circle-fill text-blue-500 text-base';
});
const bannerLabel = computed(() => {
  if (isThreadsFeed.value) {
    if (isQuote.value) return t('CONVERSATION.THREADS_FEED.QUOTED_IN_POST');
    if (isMention.value)
      return t('CONVERSATION.THREADS_FEED.MENTIONED_IN_POST');
    return t('CONVERSATION.THREADS_FEED.ORIGINAL_POST');
  }
  if (isInstagramFeed.value) {
    if (isMention.value)
      return t('CONVERSATION.INSTAGRAM_FEED.MENTIONED_IN_POST');
    return t('CONVERSATION.INSTAGRAM_FEED.ORIGINAL_POST');
  }
  if (isVisitorPost.value) return t('CONVERSATION.FACEBOOK_FEED.VISITOR_POST');
  if (isMention.value) return t('CONVERSATION.FACEBOOK_FEED.MENTIONED_IN_POST');
  if (isAd.value) return t('CONVERSATION.FACEBOOK_FEED.SPONSORED_POST');
  return t('CONVERSATION.FACEBOOK_FEED.ORIGINAL_POST');
});
const viewLinkLabel = computed(() => {
  if (isThreadsFeed.value)
    return t('CONVERSATION.THREADS_FEED.VIEW_ON_THREADS');
  if (isInstagramFeed.value)
    return t('CONVERSATION.INSTAGRAM_FEED.VIEW_ON_INSTAGRAM');
  return t('CONVERSATION.FACEBOOK_FEED.VIEW_ON_FACEBOOK');
});
</script>

<template>
  <div
    v-if="isSupportedFeed && hasAnyContent"
    class="mx-4 mt-3 mb-2 rounded-lg border border-n-weak bg-n-solid-1 p-3 flex flex-col gap-2"
  >
    <div class="flex items-center justify-between">
      <span
        class="text-xs font-medium uppercase tracking-wide text-n-slate-11 flex items-center gap-1.5"
      >
        <i :class="iconClass" />
        {{ bannerLabel }}
      </span>
      <a
        v-if="permalinkUrl"
        :href="permalinkUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="text-xs text-n-brand hover:underline flex items-center gap-1"
      >
        {{ viewLinkLabel }}
        <i class="i-ri-external-link-line" />
      </a>
    </div>
    <p
      v-if="postContent"
      class="text-sm text-n-slate-12 whitespace-pre-wrap line-clamp-4"
    >
      {{ postContent }}
    </p>
    <div v-if="mediaUrl" class="rounded-md overflow-hidden max-w-xs">
      <video
        v-if="isVideo"
        :src="mediaUrl"
        controls
        class="w-full max-h-48 object-cover"
      />
      <img v-else :src="mediaUrl" alt="" class="w-full max-h-48 object-cover" />
    </div>
  </div>
</template>
