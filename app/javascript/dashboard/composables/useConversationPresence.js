import { onMounted, onBeforeUnmount, watch } from 'vue';
import { useStore } from 'vuex';

const VIEWING_REFRESH_MS = 60_000; // re-emit viewing_on every 60s as keepalive
const inflight = new Map(); // displayId -> last sent timestamp (ms)

// Resolve window.axios at call-time. It's assigned in entrypoints/dashboard.js
// AFTER this module is imported via the router graph, so capturing it at
// module top is always undefined and throws TypeError on every call —
// which corrupts lifecycle hooks and breaks subsequent navigation.
const post = (accountId, displayId, status) => {
  const axios = window.axios;
  if (!axios || !accountId || !displayId) return Promise.resolve();
  // Debounce: ≤ 1 viewing_on per second per conversation
  if (status === 'on') {
    const last = inflight.get(displayId) || 0;
    if (Date.now() - last < 1_000) return Promise.resolve();
    inflight.set(displayId, Date.now());
  }
  return axios
    .post(
      `/api/v1/accounts/${accountId}/conversations/${displayId}/toggle_viewing`,
      { status }
    )
    .catch(() => {
      /* best-effort */
    });
};

// Banking demo (#6): emit conversation.viewing_on while the agent has the
// conversation open, viewing_off when they leave / hide the tab. Other
// agents see the avatar stack live via cable broadcasts.
export const useConversationPresence = displayIdRef => {
  const store = useStore();
  const accountId = () => store.getters.getCurrentAccountId;
  let keepaliveTimer = null;

  const stopKeepalive = () => {
    if (keepaliveTimer) {
      clearInterval(keepaliveTimer);
      keepaliveTimer = null;
    }
  };

  const startKeepalive = id => {
    stopKeepalive();
    keepaliveTimer = setInterval(
      () => post(accountId(), id, 'on'),
      VIEWING_REFRESH_MS
    );
  };

  const enter = id => {
    if (!id) return;
    post(accountId(), id, 'on');
    startKeepalive(id);
  };

  const leave = id => {
    if (!id) return;
    stopKeepalive();
    inflight.delete(id);
    post(accountId(), id, 'off');
  };

  const onVisibilityChange = () => {
    const id = displayIdRef.value;
    if (!id) return;
    if (document.hidden) leave(id);
    else enter(id);
  };

  onMounted(() => {
    enter(displayIdRef.value);
    document.addEventListener('visibilitychange', onVisibilityChange);
  });

  onBeforeUnmount(() => {
    document.removeEventListener('visibilitychange', onVisibilityChange);
    leave(displayIdRef.value);
  });

  watch(displayIdRef, (next, prev) => {
    if (prev) leave(prev);
    if (next) enter(next);
  });
};
