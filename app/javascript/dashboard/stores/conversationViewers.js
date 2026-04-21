import { defineStore } from 'pinia';

// Banking demo (#6): real-time "who has this conversation open" presence.
// Populated by the `conversation.viewing_on` / `conversation.viewing_off`
// ActionCable events (see actionCable.js). Keyed by conversation display_id
// → { [userId]: { id, name, thumbnail, last_seen_ms } }. Entries older than
// TTL_MS are treated as stale and pruned on read so a crashed tab can't
// keep a ghost avatar on screen forever.
const TTL_MS = 3 * 60 * 1000; // 3 min — backend keepalive is every 60s

export const useConversationViewersStore = defineStore('conversationViewers', {
  state: () => ({
    viewersByConversation: {},
  }),

  getters: {
    viewersFor: state => (displayId, excludeUserId) => {
      const bucket = state.viewersByConversation[displayId] || {};
      const now = Date.now();
      return Object.values(bucket).filter(
        v => v.id !== excludeUserId && now - (v.last_seen_ms || 0) < TTL_MS
      );
    },
  },

  actions: {
    addViewer(displayId, user) {
      if (!displayId || !user?.id) return;
      const bucket = this.viewersByConversation[displayId] || {};
      bucket[user.id] = {
        id: user.id,
        name: user.name || user.available_name,
        thumbnail: user.thumbnail || user.avatar_url || '',
        last_seen_ms: Date.now(),
      };
      this.viewersByConversation[displayId] = { ...bucket };
    },

    removeViewer(displayId, userId) {
      if (!displayId || !userId) return;
      const bucket = this.viewersByConversation[displayId];
      if (!bucket) return;
      // eslint-disable-next-line no-param-reassign
      delete bucket[userId];
      this.viewersByConversation[displayId] = { ...bucket };
    },
  },
});
