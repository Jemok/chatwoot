<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useConversationViewersStore } from 'dashboard/stores/conversationViewers';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const store = useStore();
const viewersStore = useConversationViewersStore();
const currentUser = computed(() => store.getters.getCurrentUser);

// Banking demo (#6): "others" are every agent broadcasting viewing presence
// except us (the store's getter already filters self out). We always render
// the stack including a "You" chip so the soft-prevention indicator is
// visible even in a single-agent demo session — as soon as a second agent
// opens the same conversation, their avatar joins the row.
const others = computed(() =>
  viewersStore.viewersFor(props.conversationId, currentUser.value?.id)
);

const self = computed(() => ({
  id: currentUser.value?.id,
  name: currentUser.value?.name || 'You',
  thumbnail: currentUser.value?.avatar_url || '',
}));

const label = computed(() => {
  if (!others.value.length) return 'Only you are viewing';
  const names = others.value.map(v => v.name).join(', ');
  return `You + ${names}`;
});
</script>

<template>
  <div
    v-tooltip.bottom="label"
    class="flex items-center gap-1.5 pl-1 pr-2 py-0.5 rounded-full bg-n-slate-2 border border-n-slate-4"
  >
    <span class="i-ph-eye-fill text-n-slate-11 text-sm" />
    <div class="flex items-center -space-x-1.5">
      <span class="ring-2 ring-n-background rounded-full">
        <Avatar
          :name="self.name"
          :src="self.thumbnail"
          :size="20"
          rounded-full
        />
      </span>
      <span
        v-for="viewer in others.slice(0, 3)"
        :key="viewer.id"
        v-tooltip.bottom="`${viewer.name} is viewing`"
        class="ring-2 ring-n-background rounded-full"
      >
        <Avatar
          :name="viewer.name"
          :src="viewer.thumbnail"
          :size="20"
          rounded-full
        />
      </span>
      <span
        v-if="others.length > 3"
        class="ring-2 ring-n-background rounded-full bg-n-slate-3 text-n-slate-11 text-[10px] font-medium w-5 h-5 flex items-center justify-center"
      >
        +{{ others.length - 3 }}
      </span>
    </div>
    <span class="text-[11px] font-medium text-n-slate-11">
      {{ others.length + 1 }}
    </span>
  </div>
</template>
