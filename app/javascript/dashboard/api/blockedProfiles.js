/* global axios */
import ApiClient from './ApiClient';

// Banking demo: small API wrapper for the Profile Blocks registry.
// Supports both the "raw" admin form (channel_type + platform_user_id) and
// the inline conversation shortcut (just conversation_id — backend resolves).
class BlockedProfilesApi extends ApiClient {
  constructor() {
    super('blocked_profiles', { accountScoped: true });
  }

  list(channelType) {
    return axios.get(this.url, {
      params: channelType ? { channel_type: channelType } : {},
    });
  }

  block({
    channelType,
    platformUserId,
    contactId,
    conversationId,
    reason,
    durationHours,
  }) {
    return axios.post(this.url, {
      blocked_profile: {
        channel_type: channelType,
        platform_user_id: platformUserId,
        contact_id: contactId,
        reason,
      },
      conversation_id: conversationId,
      duration_hours: durationHours,
      reason,
    });
  }

  unblock(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new BlockedProfilesApi();
