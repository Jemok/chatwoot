<script setup>
import { ref, computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

// Banking demo: simple modal to edit an outgoing reply. The backend decides
// whether the edit can be propagated to the external channel or not — the
// response includes a `simulated` flag that we surface in the success toast.
const props = defineProps({
  show: { type: Boolean, required: true },
  message: { type: Object, required: true },
});
const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const draft = ref(props.message.content || '');
const isSaving = ref(false);

const canSave = computed(
  () => draft.value.trim().length > 0 && draft.value !== props.message.content
);

const conversationId = computed(
  () => props.message.conversation_id ?? props.message.conversationId
);

const handleSave = async () => {
  if (!canSave.value || isSaving.value) return;
  isSaving.value = true;
  try {
    const data = await store.dispatch('editMessage', {
      conversationId: conversationId.value,
      messageId: props.message.id,
      content: draft.value,
    });
    const msg = data?.simulated
      ? t('CONVERSATION.CONTEXT_MENU.EDIT.SUCCESS_SIMULATED')
      : t('CONVERSATION.CONTEXT_MENU.EDIT.SUCCESS');
    useAlert(msg);
    emit('close');
  } catch (error) {
    const apiMsg = error?.response?.data?.error;
    useAlert(apiMsg || t('CONVERSATION.CONTEXT_MENU.EDIT.FAILED'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <woot-modal :show="props.show" :on-close="() => emit('close')">
    <div class="p-6">
      <h2 class="text-lg font-medium text-n-slate-12 mb-4">
        {{ $t('CONVERSATION.CONTEXT_MENU.EDIT.TITLE') }}
      </h2>
      <textarea
        v-model="draft"
        class="w-full min-h-[120px] rounded-md border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :placeholder="$t('CONVERSATION.CONTEXT_MENU.EDIT.PLACEHOLDER')"
      />
      <p class="mt-2 text-xs text-n-slate-11">
        {{ $t('CONVERSATION.CONTEXT_MENU.EDIT.HINT') }}
      </p>
      <div class="mt-4 flex items-center justify-end gap-2">
        <button
          type="button"
          class="px-4 py-2 text-sm rounded-md border border-n-weak text-n-slate-12 hover:bg-n-alpha-1"
          :disabled="isSaving"
          @click="emit('close')"
        >
          {{ $t('CONVERSATION.CONTEXT_MENU.EDIT.CANCEL') }}
        </button>
        <button
          type="button"
          class="px-4 py-2 text-sm rounded-md bg-n-brand text-white hover:bg-n-brand/90 disabled:opacity-50"
          :disabled="!canSave || isSaving"
          @click="handleSave"
        >
          {{ $t('CONVERSATION.CONTEXT_MENU.EDIT.SAVE') }}
        </button>
      </div>
    </div>
  </woot-modal>
</template>
