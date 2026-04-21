<script>
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import AddCannedModal from 'dashboard/routes/dashboard/settings/canned/AddCanned.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { conversationUrl, frontendURL } from '../../../helper/URLHelper';
import {
  ACCOUNT_EVENTS,
  CONVERSATION_EVENTS,
} from '../../../helper/AnalyticsHelper/events';
import MenuItem from '../../../components/widgets/conversation/contextMenu/menuItem.vue';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import EditMessageModal from './EditMessageModal.vue';
import BlockedProfilesApi from 'dashboard/api/blockedProfiles';

export default {
  components: {
    AddCannedModal,
    MenuItem,
    ContextMenu,
    NextButton,
    EditMessageModal,
  },
  props: {
    message: {
      type: Object,
      required: true,
    },
    isOpen: {
      type: Boolean,
      default: false,
    },
    enabledOptions: {
      type: Object,
      default: () => ({}),
    },
    contextMenuPosition: {
      type: Object,
      default: () => ({}),
    },
    hideButton: {
      type: Boolean,
      default: false,
    },
    // Banking demo: channel type of the parent inbox, used to switch on
    // per-channel moderation labels ("Hide on Facebook" vs generic Hide).
    channelType: {
      type: String,
      default: '',
    },
  },
  emits: ['open', 'close', 'replyTo'],
  setup() {
    const { getPlainText } = useMessageFormatter();

    return {
      getPlainText,
    };
  },
  data() {
    return {
      isCannedResponseModalOpen: false,
      showDeleteModal: false,
      showEditModal: false,
    };
  },
  computed: {
    ...mapGetters({
      getAccount: 'accounts/getAccount',
      currentAccountId: 'getCurrentAccountId',
      getUISettings: 'getUISettings',
    }),
    plainTextContent() {
      return this.getPlainText(this.messageContent);
    },
    conversationId() {
      return this.message.conversation_id ?? this.message.conversationId;
    },
    messageId() {
      return this.message.id;
    },
    messageContent() {
      return this.message.content;
    },
    contentAttributes() {
      return useSnakeCase(
        this.message.content_attributes ?? this.message.contentAttributes
      );
    },
    // Banking demo: pretty label for per-channel moderation menu items.
    moderationPlatformLabel() {
      const map = {
        'Channel::FacebookPage': 'Facebook',
        'Channel::Instagram': 'Instagram',
        'Channel::Tiktok': 'TikTok',
      };
      return map[this.channelType] || 'platform';
    },
  },
  methods: {
    async copyLinkToMessage() {
      const fullConversationURL =
        window.chatwootConfig.hostURL +
        frontendURL(
          conversationUrl({
            id: this.conversationId,
            accountId: this.currentAccountId,
          })
        );
      await copyTextToClipboard(
        `${fullConversationURL}?messageId=${this.messageId}`
      );
      useAlert(this.$t('CONVERSATION.CONTEXT_MENU.LINK_COPIED'));
      this.handleClose();
    },
    async handleCopy() {
      await copyTextToClipboard(this.plainTextContent);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
      this.handleClose();
    },
    showCannedResponseModal() {
      useTrack(ACCOUNT_EVENTS.ADDED_TO_CANNED_RESPONSE);
      this.isCannedResponseModalOpen = true;
    },
    hideCannedResponseModal() {
      this.isCannedResponseModalOpen = false;
      this.handleClose();
    },
    handleOpen(e) {
      this.$emit('open', e);
    },
    handleClose(e) {
      this.$emit('close', e);
    },
    handleTranslate() {
      const { locale: accountLocale } = this.getAccount(this.currentAccountId);
      const agentLocale = this.getUISettings?.locale;
      const targetLanguage = agentLocale || accountLocale || 'en';
      this.$store.dispatch('translateMessage', {
        conversationId: this.conversationId,
        messageId: this.messageId,
        targetLanguage,
      });
      useTrack(CONVERSATION_EVENTS.TRANSLATE_A_MESSAGE);
      this.handleClose();
    },
    handleReplyTo() {
      this.$emit('replyTo', this.message);
      this.handleClose();
    },
    openDeleteModal() {
      this.handleClose();
      this.showDeleteModal = true;
    },
    async confirmDeletion() {
      try {
        await this.$store.dispatch('deleteMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
        });
        useAlert(this.$t('CONVERSATION.SUCCESS_DELETE_MESSAGE'));
        this.handleClose();
      } catch (error) {
        useAlert(this.$t('CONVERSATION.FAIL_DELETE_MESSSAGE'));
      }
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
    },
    // Banking demo: open/close edit modal for outgoing messages.
    openEditModal() {
      this.handleClose();
      this.showEditModal = true;
    },
    closeEditModal() {
      this.showEditModal = false;
    },
    async moderateMessage(actionType) {
      const reasonKeys = {
        hide: 'CONVERSATION.CONTEXT_MENU.MODERATE.REASON_HIDE',
        unhide: 'CONVERSATION.CONTEXT_MENU.MODERATE.REASON_UNHIDE',
      };
      const label = this.$t(
        reasonKeys[actionType] ||
          'CONVERSATION.CONTEXT_MENU.MODERATE.REASON_DELETE'
      );
      const reason = window.prompt(label, '');
      if (reason === null) return;
      this.handleClose();
      try {
        const res = await this.$store.dispatch('moderateMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          actionType,
          reason,
        });
        const msg = res?.simulated
          ? this.$t('CONVERSATION.CONTEXT_MENU.MODERATE.SUCCESS_SIMULATED')
          : this.$t('CONVERSATION.CONTEXT_MENU.MODERATE.SUCCESS');
        useAlert(msg);
      } catch (e) {
        useAlert(
          e?.response?.data?.error ||
            this.$t('CONVERSATION.CONTEXT_MENU.MODERATE.FAILED')
        );
      }
    },
    // Banking demo: block the remote profile from interacting with our
    // page. Backend resolves channel_type + platform_user_id from the
    // conversation's contact_inbox and (when not simulated) calls the
    // platform API (FB Graph `/{page-id}/blocked`). Writes a
    // `profile_block` audit row either way.
    async blockProfile() {
      const reason = window.prompt(
        this.$t('CONVERSATION.CONTEXT_MENU.BLOCK_PROFILE.REASON_PROMPT', {
          platform: this.moderationPlatformLabel,
        }),
        ''
      );
      if (reason === null) return;
      const durationHours = window.prompt(
        this.$t('CONVERSATION.CONTEXT_MENU.BLOCK_PROFILE.DURATION_PROMPT'),
        '0'
      );
      if (durationHours === null) return;
      this.handleClose();
      try {
        const { data } = await BlockedProfilesApi.block({
          conversationId: this.conversationId,
          reason,
          durationHours: Number(durationHours) || 0,
        });
        const msg = data?.platform?.simulated
          ? this.$t('CONVERSATION.CONTEXT_MENU.BLOCK_PROFILE.SUCCESS_SIMULATED')
          : this.$t('CONVERSATION.CONTEXT_MENU.BLOCK_PROFILE.SUCCESS', {
              platform: this.moderationPlatformLabel,
            });
        useAlert(msg);
      } catch (e) {
        useAlert(
          e?.response?.data?.error ||
            this.$t('CONVERSATION.CONTEXT_MENU.BLOCK_PROFILE.FAILED')
        );
      }
    },
  },
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div class="context-menu">
    <!-- Add To Canned Responses -->
    <woot-modal
      v-if="isCannedResponseModalOpen && enabledOptions['cannedResponse']"
      v-model:show="isCannedResponseModalOpen"
      :on-close="hideCannedResponseModal"
    >
      <AddCannedModal
        :response-content="plainTextContent"
        :on-close="hideCannedResponseModal"
      />
    </woot-modal>
    <!-- Confirm Deletion -->
    <woot-delete-modal
      v-if="showDeleteModal && enabledOptions['delete']"
      v-model:show="showDeleteModal"
      class="context-menu--delete-modal"
      :on-close="closeDeleteModal"
      :on-confirm="confirmDeletion"
      :title="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.TITLE')"
      :message="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.MESSAGE')"
      :confirm-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.DELETE')"
      :reject-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.CANCEL')"
    />
    <!-- Banking demo: edit outgoing reply modal -->
    <EditMessageModal
      v-if="showEditModal && enabledOptions['edit']"
      :show="showEditModal"
      :message="message"
      @close="closeEditModal"
    />
    <NextButton
      v-if="!hideButton"
      ghost
      slate
      sm
      icon="i-lucide-ellipsis-vertical"
      class="invisible group-hover/context-menu:visible"
      @click="handleOpen"
    />
    <ContextMenu
      v-if="isOpen && !isCannedResponseModalOpen"
      :x="contextMenuPosition.x"
      :y="contextMenuPosition.y"
      @close="handleClose"
    >
      <div class="menu-container">
        <MenuItem
          v-if="enabledOptions['replyTo']"
          :option="{
            icon: 'arrow-reply',
            label: $t('CONVERSATION.CONTEXT_MENU.REPLY_TO'),
          }"
          variant="icon"
          @click.stop="handleReplyTo"
        />
        <MenuItem
          v-if="enabledOptions['copy']"
          :option="{
            icon: 'clipboard',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY'),
          }"
          variant="icon"
          @click.stop="handleCopy"
        />
        <MenuItem
          v-if="enabledOptions['translate']"
          :option="{
            icon: 'translate',
            label: $t('CONVERSATION.CONTEXT_MENU.TRANSLATE'),
          }"
          variant="icon"
          @click.stop="handleTranslate"
        />
        <hr />
        <MenuItem
          v-if="enabledOptions['copyLink']"
          :option="{
            icon: 'link',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY_PERMALINK'),
          }"
          variant="icon"
          @click.stop="copyLinkToMessage"
        />
        <MenuItem
          v-if="enabledOptions['cannedResponse']"
          :option="{
            icon: 'comment-add',
            label: $t('CONVERSATION.CONTEXT_MENU.CREATE_A_CANNED_RESPONSE'),
          }"
          variant="icon"
          @click.stop="showCannedResponseModal"
        />
        <hr v-if="enabledOptions['delete'] || enabledOptions['edit']" />
        <MenuItem
          v-if="enabledOptions['edit']"
          :option="{
            icon: 'edit',
            label: $t('CONVERSATION.CONTEXT_MENU.EDIT.MENU_LABEL'),
          }"
          variant="icon"
          @click.stop="openEditModal"
        />
        <MenuItem
          v-if="enabledOptions['moderateHide']"
          :option="{
            icon: 'eye-hide',
            label: $t('CONVERSATION.CONTEXT_MENU.MODERATE.HIDE', {
              platform: moderationPlatformLabel,
            }),
          }"
          variant="icon"
          @click.stop="moderateMessage('hide')"
        />
        <MenuItem
          v-if="enabledOptions['moderateUnhide']"
          :option="{
            icon: 'eye-show',
            label: $t('CONVERSATION.CONTEXT_MENU.MODERATE.UNHIDE', {
              platform: moderationPlatformLabel,
            }),
          }"
          variant="icon"
          @click.stop="moderateMessage('unhide')"
        />
        <MenuItem
          v-if="enabledOptions['moderateDelete']"
          :option="{
            icon: 'delete',
            label: $t('CONVERSATION.CONTEXT_MENU.MODERATE.DELETE', {
              platform: moderationPlatformLabel,
            }),
          }"
          variant="icon"
          @click.stop="moderateMessage('delete')"
        />
        <MenuItem
          v-if="enabledOptions['blockProfile']"
          :option="{
            icon: 'dismiss-circle',
            label: $t('CONVERSATION.CONTEXT_MENU.BLOCK_PROFILE.MENU_LABEL', {
              platform: moderationPlatformLabel,
            }),
          }"
          variant="icon"
          @click.stop="blockProfile"
        />
        <MenuItem
          v-if="enabledOptions['delete']"
          :option="{
            icon: 'delete',
            label: $t('CONVERSATION.CONTEXT_MENU.DELETE'),
          }"
          variant="icon"
          @click.stop="openDeleteModal"
        />
      </div>
    </ContextMenu>
  </div>
</template>

<style lang="scss" scoped>
.menu-container {
  @apply p-1 bg-n-background shadow-xl rounded-md;

  hr:first-child {
    @apply hidden;
  }

  hr {
    @apply m-1 border-b border-solid border-n-strong;
  }
}

.context-menu--delete-modal {
  ::v-deep {
    .modal-container {
      @apply max-w-[30rem];

      h2 {
        @apply font-medium text-base;
      }
    }
  }
}
</style>
