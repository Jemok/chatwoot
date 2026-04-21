/* global axios */
import ApiClient from '../ApiClient';

class YoutubeChannel extends ApiClient {
  constructor() {
    super('youtube', { accountScoped: true });
  }

  generateAuthorization(payload) {
    return axios.post(`${this.url}/authorization`, payload);
  }
}

export default new YoutubeChannel();
