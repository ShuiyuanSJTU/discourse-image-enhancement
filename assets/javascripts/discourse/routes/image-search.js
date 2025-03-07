import Route from "@ember/routing/route";

export default class extends Route {
  queryParams = {};

  setupController(controller) {
    if (controller.q) {
      controller.set("searchTerm", controller.q);
      controller.search();
    }
  }
}
