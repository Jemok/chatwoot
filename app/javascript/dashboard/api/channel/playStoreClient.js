/* global axios */
import ApiClient from '../ApiClient';

class PlayStoreChannel extends ApiClient {
  constructor() {
    super('play_store_channel', { accountScoped: true });
  }

  create(payload) {
    return axios.post(this.url, payload);
  }
}

export default new PlayStoreChannel();
