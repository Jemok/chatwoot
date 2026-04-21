import Auth from '../api/auth';
import { markSuspended, SUSPENSION_MATCH } from './suspensionState';

const parseErrorCode = error => {
  // Banking demo: detect "Your account is suspended" 401 emitted by
  // EnsureCurrentAccountHelper#account_accessible_for_user? and surface it
  // as a full-screen UI flag instead of letting every request silently fail.
  const status = error?.response?.status;
  const message = error?.response?.data?.error;
  if (
    status === 401 &&
    typeof message === 'string' &&
    SUSPENSION_MATCH.test(message)
  ) {
    markSuspended(message);
  }
  return Promise.reject(error);
};

export default axios => {
  const { apiHost = '' } = window.chatwootConfig || {};
  const wootApi = axios.create({ baseURL: `${apiHost}/` });
  // Add Auth Headers to requests if logged in
  if (Auth.hasAuthCookie()) {
    const {
      'access-token': accessToken,
      'token-type': tokenType,
      client,
      expiry,
      uid,
    } = Auth.getAuthData();
    Object.assign(wootApi.defaults.headers.common, {
      'access-token': accessToken,
      'token-type': tokenType,
      client,
      expiry,
      uid,
    });
  }
  // Response parsing interceptor
  wootApi.interceptors.response.use(
    response => response,
    error => parseErrorCode(error)
  );
  // Banking demo: also install the suspension interceptor on the default
  // axios module so any `import axios from 'axios'` call (Pinia stores,
  // ad-hoc components) also flips the global flag when the server returns
  // the suspension 401. Without this the overlay only appears after a
  // re-login because most store calls bypass `window.axios`.
  axios.interceptors.response.use(
    response => response,
    error => parseErrorCode(error)
  );
  return wootApi;
};
