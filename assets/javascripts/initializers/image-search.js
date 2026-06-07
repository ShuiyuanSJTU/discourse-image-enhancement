import { withPluginApi } from "discourse/lib/plugin-api";

function initializePlugin(api) {
  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("service:site-settings");

  if (!currentUser || !siteSettings.image_search_enabled) {
    return;
  }

  api.addFullPageSearchType(
    "search.type.images",
    "images",
    // eslint-disable-next-line no-unused-vars
    function (controller, args, searchKey) {
      controller.setProperties({
        searching: false,
        loading: false,
      });
      const router = api._lookupContainer("service:router");
      router.transitionTo("image-search", { queryParams: { q: args.q } });
    }
  );
}

export default {
  name: "image-search",
  initialize: function () {
    withPluginApi((api) => initializePlugin(api));
  },
};
