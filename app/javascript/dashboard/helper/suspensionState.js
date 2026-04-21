// Banking demo: global reactive flag flipped by the axios response
// interceptor whenever the backend returns the "account suspended" 401.
// App.vue watches this to show a full-screen overlay instead of the
// infinite spinner that you'd otherwise get when every account-scoped
// request 401s.
import { ref } from 'vue';

export const isAccountSuspended = ref(false);
export const suspensionMessage = ref('');

export const SUSPENSION_MATCH = /your account is suspended/i;

export const markSuspended = message => {
  isAccountSuspended.value = true;
  suspensionMessage.value = message || '';
};

export const clearSuspended = () => {
  isAccountSuspended.value = false;
  suspensionMessage.value = '';
};
