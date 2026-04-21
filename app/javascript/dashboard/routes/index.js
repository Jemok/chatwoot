import { createRouter, createWebHistory } from 'vue-router';

import { frontendURL } from '../helper/URLHelper';
import dashboard from './dashboard/dashboard.routes';
import store from 'dashboard/store';
import { validateLoggedInRoutes } from '../helper/routeHelpers';
import AnalyticsHelper from '../helper/AnalyticsHelper';
import { isAccountSuspended } from '../helper/suspensionState';

const routes = [...dashboard.routes];

export const router = createRouter({ history: createWebHistory(), routes });

// Banking demo (Phase 2 #7 + Phase 3 #3): role-specific landing.
// Admin                   → Demo Coverage Map (executive entry point)
// Supervisor / custom role → Filtered Inbox   (operational dashboard)
// Everyone else           → conversations     (stock agent entry point)
const roleLandingPath = (user, accountId) => {
  const acc = (user.accounts || []).find(a => a.id === accountId);
  if (!acc) return 'dashboard';
  if (acc.role === 'administrator') return 'demo-coverage';
  const cr = (acc.custom_role?.name || acc.permissions || [])
    .toString()
    .toLowerCase();
  if (cr.includes('supervisor')) return 'filtered-inbox';
  return 'dashboard';
};

export const validateAuthenticateRoutePermission = (to, next) => {
  const { isLoggedIn, getCurrentUser: user } = store.getters;

  if (!isLoggedIn) {
    // Banking demo: if the 401 was a suspension, stay mounted so the
    // SuspendedAccountOverlay can render instead of redirecting to login.
    if (isAccountSuspended.value) {
      return '';
    }
    window.location.assign('/app/login');
    return '';
  }

  const { accounts = [], account_id: accountId } = user;

  if (!accounts.length) {
    if (to.name === 'no_accounts') {
      return next();
    }
    return next(frontendURL('no-accounts'));
  }

  if (to.name === 'no_accounts' || !to.name) {
    return next(
      frontendURL(`accounts/${accountId}/${roleLandingPath(user, accountId)}`)
    );
  }

  const nextRoute = validateLoggedInRoutes(to, store.getters.getCurrentUser);
  return nextRoute ? next(frontendURL(nextRoute)) : next();
};

export const initalizeRouter = () => {
  const userAuthentication = store.dispatch('setUser');

  router.beforeEach((to, _from, next) => {
    AnalyticsHelper.page(to.name || '', {
      path: to.path,
      name: to.name,
    });

    userAuthentication.then(() => {
      return validateAuthenticateRoutePermission(to, next, store);
    });
  });
};

export default router;
