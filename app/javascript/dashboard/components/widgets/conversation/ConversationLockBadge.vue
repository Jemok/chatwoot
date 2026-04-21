<script setup>
import { computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { useStore } from 'vuex';
import { useConversationLocksStore } from 'dashboard/stores/conversationLocks';
import { useAdmin } from 'dashboard/composables/useAdmin';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const store = useStore();
const { isAdmin } = useAdmin();
const locksStore = useConversationLocksStore();
const accountId = computed(() => store.getters.getCurrentAccountId);
const currentUser = computed(() => store.getters.getCurrentUser);

const lock = computed(() => locksStore.lockFor(props.conversationId));
const lockedByOther = computed(() =>
  locksStore.isLockedByOther(props.conversationId, currentUser.value?.id)
);

// Banking demo: GET the current lock first. If it's held by another agent,
// surface the amber banner immediately without attempting to acquire (which
// would just 409 and arrive later). If free, try to acquire it ourselves.
const syncLock = async () => {
  const existing = await locksStore.fetch(
    accountId.value,
    props.conversationId
  );
  if (existing?.locked && existing.user_id !== currentUser.value?.id) return;
  await locksStore.acquire(accountId.value, props.conversationId);
};

const release = () => locksStore.release(accountId.value, props.conversationId);

const takeover = async () => {
  const r = await locksStore.takeover(accountId.value, props.conversationId);
  if (r.ok) await syncLock();
};

onMounted(syncLock);
onBeforeUnmount(release);
watch(
  () => props.conversationId,
  (next, prev) => {
    if (prev) locksStore.release(accountId.value, prev);
    if (next) syncLock();
  }
);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div
    v-if="lockedByOther"
    class="flex items-center justify-between gap-2 px-3 py-2 mx-2 my-1 rounded-md bg-amber-50 border border-amber-200"
  >
    <div class="flex items-center gap-2 text-sm text-amber-900">
      <span class="i-ph-lock-fill text-amber-700" />
      <span>
        Locked by <strong>{{ lock.user_name }}</strong> — replies disabled to
        prevent collision.
      </span>
    </div>
    <button
      v-if="isAdmin"
      type="button"
      class="text-xs px-2 py-1 rounded bg-amber-600 text-white hover:bg-amber-700"
      @click="takeover"
    >
      Supervisor takeover
    </button>
  </div>
  <div
    v-else-if="lock?.held_by_me"
    class="flex items-center gap-2 px-3 py-1.5 mx-2 my-1 rounded-md bg-emerald-50 border border-emerald-200 text-xs font-medium text-emerald-900"
  >
    <span class="i-ph-lock-key-fill text-emerald-600 text-sm" />
    <span
      >You hold the response lock — other agents can view but cannot send.</span
    >
  </div>
</template>
