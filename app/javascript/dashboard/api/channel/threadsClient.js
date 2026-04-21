/* global axios */
import ApiClient from '../ApiClient';

class ThreadsChannel extends ApiClient {
  constructor() {
    super('threads', { accountScoped: true });
  }

  generateAuthorization(payload) {
    return axios.post(`${this.url}/authorization`, payload);
  }
}

export default new ThreadsChannel();
