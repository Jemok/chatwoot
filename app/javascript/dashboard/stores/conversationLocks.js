import { defineStore } from 'pinia';

// Banking demo: use the configured axios instance (auth headers injected by
// APIHelper + interceptors). Bare `import axios from 'axios'` sends requests
// without the access-token/client/uid headers → 401 and no lock state.
const api = () => window.axios;

const baseUrl = accountId => `/api/v1/accounts/${accountId}/conversation_locks`;

// Banking demo (#7): single-active-responder lock state. Acquired when a
// conversation is opened, refreshed every 60s, released on close. Conflict
// state surfaces a banner; supervisors can force takeover.
export const useConversationLocksStore = defineStore('conversationLocks', {
  state: () => ({
    locks: {}, // keyed by displayId
    heartbeatTimers: {},
  }),

  getters: {
    lockFor: state => displayId => state.locks[displayId] || null,
    isLockedByOther: state => (displayId, currentUserId) => {
      const l = state.locks[displayId];
      return !!(l && l.locked && !l.held_by_me && l.user_id !== currentUserId);
    },
  },

  actions: {
    setLock(displayId, payload) {
      this.locks[displayId] = payload;
    },

    async acquire(accountId, displayId) {
      try {
        const { data } = await api().post(`${baseUrl(accountId)}/${displayId}`);
        this.setLock(displayId, data);
        this.startHeartbeat(accountId, displayId);
        return { ok: true, data };
      } catch (e) {
        if (e.response?.status === 409) {
          this.setLock(displayId, e.response.data.lock);
          return { ok: false, conflict: true, lock: e.response.data.lock };
        }
        return { ok: false, error: e.message };
      }
    },

    async release(accountId, displayId) {
      this.stopHeartbeat(displayId);
      try {
        await api().delete(`${baseUrl(accountId)}/${displayId}`);
      } catch (_) {
        /* swallow — best-effort release */
      }
      delete this.locks[displayId];
    },

    async heartbeat(accountId, displayId) {
      try {
        const { data } = await api().post(
          `${baseUrl(accountId)}/${displayId}/heartbeat`
        );
        this.setLock(displayId, data);
      } catch (_) {
        // lost — try re-acquire
        await this.acquire(accountId, displayId);
      }
    },

    async takeover(accountId, displayId) {
      try {
        const { data } = await api().post(
          `${baseUrl(accountId)}/${displayId}/takeover`
        );
        this.setLock(displayId, data);
        this.startHeartbeat(accountId, displayId);
        return { ok: true, data };
      } catch (e) {
        return {
          ok: false,
          error: e.response?.data?.error || e.message,
        };
      }
    },

    async fetch(accountId, displayId) {
      try {
        const { data } = await api().get(`${baseUrl(accountId)}/${displayId}`);
        this.setLock(displayId, data);
        return data;
      } catch (_) {
        return null;
      }
    },

    startHeartbeat(accountId, displayId) {
      this.stopHeartbeat(displayId);
      this.heartbeatTimers[displayId] = setInterval(
        () => this.heartbeat(accountId, displayId),
        60_000
      );
    },

    stopHeartbeat(displayId) {
      const t = this.heartbeatTimers[displayId];
      if (t) {
        clearInterval(t);
        delete this.heartbeatTimers[displayId];
      }
    },
  },
});
