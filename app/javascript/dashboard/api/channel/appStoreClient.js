/* global axios */
import ApiClient from '../ApiClient';

class AppStoreChannel extends ApiClient {
  constructor() {
    super('app_store_channel', { accountScoped: true });
  }

  create(payload) {
    return axios.post(this.url, payload);
  }
}

export default new AppStoreChannel();
