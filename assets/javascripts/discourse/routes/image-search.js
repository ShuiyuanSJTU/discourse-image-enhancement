import Route from "@ember/routing/route";

export default class extends Route {
  queryParams = {};

  setupController(controller) {
    if (controller.q) {
      controller.set("searchTerm", controller.q);
      if (controller.get("search_type") === "image_search_by_image") {
        return;
      } else if (controller.get("searchTerm")) {
        controller.search();
      }
    }
  }

  deactivate() {
    this.controller.resetSearchResult();
    this.controller.set("searchActivated", false);
  }
}
