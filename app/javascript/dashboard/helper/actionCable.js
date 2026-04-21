import AuthAPI from '../api/auth';
import BaseActionCableConnector from '../../shared/helpers/BaseActionCableConnector';
import DashboardAudioNotificationHelper from './AudioAlerts/DashboardAudioNotificationHelper';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import { useImpersonation } from 'dashboard/composables/useImpersonation';

const { isImpersonating } = useImpersonation();

class ActionCableConnector extends BaseActionCableConnector {
  constructor(app, pubsubToken) {
    const { websocketURL = '' } = window.chatwootConfig || {};
    super(app, pubsubToken, websocketURL);
    this.CancelTyping = [];
    this.events = {
      'message.created': this.onMessageCreated,
      'message.updated': this.onMessageUpdated,
      'conversation.created': this.onConversationCreated,
      'conversation.status_changed': this.onStatusChange,
      'user:logout': this.onLogout,
      'page:reload': this.onReload,
      'assignee.changed': this.onAssigneeChanged,
      'conversation.typing_on': this.onTypingOn,
      'conversation.typing_off': this.onTypingOff,
      'conversation.contact_changed': this.onConversationContactChange,
      'presence.update': this.onPresenceUpdate,
      'contact.deleted': this.onContactDelete,
      'contact.updated': this.onContactUpdate,
      'conversation.mentioned': this.onConversationMentioned,
      'notification.created': this.onNotificationCreated,
      'notification.deleted': this.onNotificationDeleted,
      'notification.updated': this.onNotificationUpdated,
      'conversation.read': this.onConversationRead,
      'conversation.updated': this.onConversationUpdated,
      'account.cache_invalidated': this.onCacheInvalidate,
      'copilot.message.created': this.onCopilotMessageCreated,
      // Banking demo (Phase 3 #4): real-time conversation lock updates so
      // collision banners flip instantly without polling.
      'conversation.lock.locked': this.onConversationLockChanged,
      'conversation.lock.unlocked': this.onConversationLockChanged,
      'conversation.lock.released': this.onConversationLockReleased,
      // Banking demo (#6): "who is viewing this conversation" presence.
      'conversation.viewing_on': this.onConversationViewingOn,
      'conversation.viewing_off': this.onConversationViewingOff,
      // Banking demo (Feature 1): when the agent's shift ends, the sweep job
      // (or the demo simulator) broadcasts this event to their pubsub_token.
      // Force availability=offline locally + pop a toast so the dashboard
      // visibly reflects "off shift" without requiring a hard logout.
      'user.shift.ended': this.onShiftEnded,
    };
  }

  // eslint-disable-next-line class-methods-use-this
  onReconnect = () => {
    emitter.emit(BUS_EVENTS.WEBSOCKET_RECONNECT);
  };

  // eslint-disable-next-line class-methods-use-this
  onDisconnected = () => {
    emitter.emit(BUS_EVENTS.WEBSOCKET_DISCONNECT);
  };

  isAValidEvent = data => {
    return this.app.$store.getters.getCurrentAccountId === data.account_id;
  };

  onMessageUpdated = data => {
    this.app.$store.dispatch('updateMessage', data);
  };

  onPresenceUpdate = data => {
    if (isImpersonating.value) return;
    this.app.$store.dispatch('contacts/updatePresence', data.contacts);
    this.app.$store.dispatch('agents/updatePresence', data.users);
    this.app.$store.dispatch('setCurrentUserAvailability', data.users);
  };

  onConversationContactChange = payload => {
    const { meta = {}, id: conversationId } = payload;
    const { sender } = meta || {};
    if (conversationId) {
      this.app.$store.dispatch('updateConversationContact', {
        conversationId,
        ...sender,
      });
    }
  };

  onAssigneeChanged = payload => {
    const { id } = payload;
    if (id) {
      this.app.$store.dispatch('updateConversation', payload);
    }
    this.fetchConversationStats();
  };

  onConversationCreated = data => {
    this.app.$store.dispatch('addConversation', data);
    this.fetchConversationStats();
  };

  onConversationRead = data => {
    this.app.$store.dispatch('updateConversation', data);
  };

  // eslint-disable-next-line class-methods-use-this
  onLogout = () => AuthAPI.logout();

  onMessageCreated = data => {
    const {
      conversation: { last_activity_at: lastActivityAt },
      conversation_id: conversationId,
    } = data;
    DashboardAudioNotificationHelper.onNewMessage(data);
    this.app.$store.dispatch('addMessage', data);
    this.app.$store.dispatch('updateConversationLastActivity', {
      lastActivityAt,
      conversationId,
    });
  };

  // eslint-disable-next-line class-methods-use-this
  onReload = () => window.location.reload();

  onStatusChange = data => {
    this.app.$store.dispatch('updateConversation', data);
    this.fetchConversationStats();
  };

  onConversationUpdated = data => {
    this.app.$store.dispatch('updateConversation', data);
    this.fetchConversationStats();
  };

  onTypingOn = ({ conversation, user }) => {
    const conversationId = conversation.id;

    this.clearTimer(conversationId);
    this.app.$store.dispatch('conversationTypingStatus/create', {
      conversationId,
      user,
    });
    this.initTimer({ conversation, user });
  };

  onTypingOff = ({ conversation, user }) => {
    const conversationId = conversation.id;

    this.clearTimer(conversationId);
    this.app.$store.dispatch('conversationTypingStatus/destroy', {
      conversationId,
      user,
    });
  };

  // Banking demo (#6): viewing presence cable handlers. Pinia store is
  // imported lazily so the cable connector keeps zero static deps on Pinia.
  onConversationMentioned = data => {
    this.app.$store.dispatch('addMentions', data);
  };

  clearTimer = conversationId => {
    const timerEvent = this.CancelTyping[conversationId];

    if (timerEvent) {
      clearTimeout(timerEvent);
      this.CancelTyping[conversationId] = null;
    }
  };

  initTimer = ({ conversation, user }) => {
    const conversationId = conversation.id;
    // Turn off typing automatically after 30 seconds
    this.CancelTyping[conversationId] = setTimeout(() => {
      this.onTypingOff({ conversation, user });
    }, 30000);
  };

  // eslint-disable-next-line class-methods-use-this
  fetchConversationStats = () => {
    emitter.emit('fetch_conversation_stats');
  };

  onContactDelete = data => {
    this.app.$store.dispatch(
      'contacts/deleteContactThroughConversations',
      data.id
    );
    this.fetchConversationStats();
  };

  onContactUpdate = data => {
    this.app.$store.dispatch('contacts/updateContact', data);
  };

  onNotificationCreated = data => {
    this.app.$store.dispatch('notifications/addNotification', data);
  };

  onNotificationDeleted = data => {
    this.app.$store.dispatch('notifications/deleteNotification', data);
  };

  onNotificationUpdated = data => {
    this.app.$store.dispatch('notifications/updateNotification', data);
  };

  onCopilotMessageCreated = data => {
    this.app.$store.dispatch('copilotMessages/upsert', data);
  };

  onCacheInvalidate = data => {
    const keys = data.cache_keys;
    this.app.$store.dispatch('labels/revalidate', { newKey: keys.label });
    this.app.$store.dispatch('inboxes/revalidate', { newKey: keys.inbox });
    this.app.$store.dispatch('teams/revalidate', { newKey: keys.team });
  };

  // Banking demo (Phase 3 #4): real-time lock updates.
  // The Pinia store keys locks by display_id; the broadcast payload includes
  // both `display_id` and the holder's `user_id` so we can rebuild the
  // `held_by_me` flag from the currently signed-in user.
  onConversationLockChanged = data => {
    if (!data?.display_id) return;
    const me = this.app.$store.getters.getCurrentUserID;
    import('dashboard/stores/conversationLocks').then(
      ({ useConversationLocksStore }) => {
        useConversationLocksStore().setLock(data.display_id, {
          locked: true,
          user_id: data.user_id,
          user_name: data.user_name,
          expires_at: data.expires_at,
          supervisor_takeover: data.supervisor_takeover,
          held_by_me: data.user_id === me,
        });
      }
    );
  };

  // eslint-disable-next-line class-methods-use-this
  onConversationLockReleased = data => {
    if (!data?.display_id) return;
    import('dashboard/stores/conversationLocks').then(
      ({ useConversationLocksStore }) => {
        useConversationLocksStore().setLock(data.display_id, {
          locked: false,
          held_by_me: false,
        });
      }
    );
  };

  // Banking demo (#6): viewing presence. Payload is
  // { conversation_id: <display_id>, user: push_event_data }.
  // Ignore our own events so the avatar stack never shows "me".
  onConversationViewingOn = data => {
    const displayId = data?.conversation_id;
    const user = data?.user;
    const me = this.app.$store.getters.getCurrentUserID;
    if (!displayId || !user?.id || user.id === me) return;
    import('dashboard/stores/conversationViewers').then(
      ({ useConversationViewersStore }) => {
        useConversationViewersStore().addViewer(displayId, user);
      }
    );
  };

  // eslint-disable-next-line class-methods-use-this
  onConversationViewingOff = data => {
    const displayId = data?.conversation_id;
    const user = data?.user;
    if (!displayId || !user?.id) return;
    import('dashboard/stores/conversationViewers').then(
      ({ useConversationViewersStore }) => {
        useConversationViewersStore().removeViewer(displayId, user.id);
      }
    );
  };

  onShiftEnded = data => {
    if (
      !data ||
      data.account_id !== this.app.$store.getters.getCurrentAccountId
    )
      return;
    this.app.$store.dispatch('updateAvailability', { availability: 'offline' });
    emitter.emit(BUS_EVENTS.SHOW_ALERT, {
      message:
        'Your shift has ended. Replies are disabled until your next scheduled shift.',
      type: 'warning',
    });
  };
}

export default {
  init(store, pubsubToken) {
    return new ActionCableConnector({ $store: store }, pubsubToken);
  },
};
