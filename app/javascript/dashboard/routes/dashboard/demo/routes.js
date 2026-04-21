import { frontendURL } from 'dashboard/helper/URLHelper';
import DemoControlPanel from './DemoControlPanel.vue';
import AuditTrail from './AuditTrail.vue';
import DemoCoverageMap from './DemoCoverageMap.vue';
import ArchitectureView from './ArchitectureView.vue';
import ChannelPerformance from './ChannelPerformance.vue';
import SecurityDashboard from './SecurityDashboard.vue';
import NpsReport from './NpsReport.vue';
import ShiftsAdmin from './ShiftsAdmin.vue';
import FilteredInbox from './FilteredInbox.vue';
import UsersLifecycle from './UsersLifecycle.vue';
import RoutingMode from './RoutingMode.vue';
import ModerationCenter from './ModerationCenter.vue';
import BlockedProfiles from './BlockedProfiles.vue';
import CsatBanking from './CsatBanking.vue';

const adm = path => ({
  path: frontendURL(`accounts/:accountId/${path}`),
  meta: { permissions: ['administrator'] },
});

export const routes = [
  { ...adm('demo'), name: 'demo_control_panel', component: DemoControlPanel },
  { ...adm('audit-trail'), name: 'audit_trail', component: AuditTrail },
  {
    ...adm('demo-coverage'),
    name: 'demo_coverage_map',
    component: DemoCoverageMap,
  },
  {
    ...adm('architecture'),
    name: 'architecture_view',
    component: ArchitectureView,
  },
  {
    ...adm('reports/channel-performance'),
    name: 'channel_performance',
    component: ChannelPerformance,
  },
  {
    ...adm('security'),
    name: 'security_dashboard',
    component: SecurityDashboard,
  },
  { ...adm('reports/nps'), name: 'nps_report', component: NpsReport },
  { ...adm('settings/shifts'), name: 'shifts_admin', component: ShiftsAdmin },
  {
    ...adm('settings/users-lifecycle'),
    name: 'users_lifecycle',
    component: UsersLifecycle,
  },
  {
    ...adm('settings/routing-mode'),
    name: 'routing_mode_admin',
    component: RoutingMode,
  },
  {
    ...adm('filtered-inbox'),
    name: 'filtered_inbox',
    component: FilteredInbox,
  },
  {
    ...adm('moderation-center'),
    name: 'moderation_center',
    component: ModerationCenter,
  },
  {
    ...adm('settings/blocked-profiles'),
    name: 'blocked_profiles_admin',
    component: BlockedProfiles,
  },
  {
    ...adm('reports/csat-banking'),
    name: 'csat_banking',
    component: CsatBanking,
  },
];
