/* global axios */
import ApiClient from '../ApiClient';

class LinkedinChannel extends ApiClient {
  constructor() {
    super('linkedin', { accountScoped: true });
  }

  generateAuthorization(payload) {
    return axios.post(`${this.url}/authorization`, payload);
  }
}

export default new LinkedinChannel();
