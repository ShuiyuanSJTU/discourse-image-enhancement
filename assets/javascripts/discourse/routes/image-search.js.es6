import Route from '@ember/routing/route';

export default class extends Route{

  queryParams = {};

  model(params, transition) {
    this.queryParams = transition.to.queryParams;
    return {};
  }

  setupController(controller) {
    const searchTerm = this.queryParams.term;
    if (searchTerm) {
      controller.set('searchTerm', searchTerm);
      controller.search();
    }
  }
}