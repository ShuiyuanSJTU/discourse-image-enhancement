import Controller from "@ember/controller";
import { action } from "@ember/object";
import { observes } from "@ember-decorators/object";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class extends Controller {
  searching = false;
  loadingMore = false;
  noMoreResults = false;
  searchActivated = false;
  searchTerm = "";
  page = 0;
  searchResults = {};
  searchResultEntries = [];
  searchResultEntriesCount = 0;
  searchButtonDisabled = false;
  expandFilters = false;
  queryParams = ["q", "search_type"];
  q = undefined;

  searchTypes = [
    {
      name: i18n("image_search.search_type.ocr_only"),
      id: "image_search_ocr",
    },
    {
      name: i18n("image_search.search_type.embed_only"),
      id: "image_search_embed",
    },
    {
      name: i18n("image_search.search_type.ocr_and_embed"),
      id: "image_search_ocr_and_embed",
    },
  ];

  search_type = this.searchTypes[0].id;

  constructor() {
    super(...arguments);
  }

  _search() {
    const searchData = {};
    searchData.term = this.get("q");
    searchData.page = this.get("page");
    switch (this.get("search_type")) {
      case "image_search_ocr_and_embed":
        searchData.ocr = true;
        searchData.embed = true;
        break;
      case "image_search_ocr":
        searchData.ocr = true;
        searchData.embed = false;
        break;
      case "image_search_embed":
        searchData.ocr = false;
        searchData.embed = true;
        break;
    }
    return ajax("/image-search/search.json", { data: searchData });
  }

  @discourseComputed("searching", "searchResultEntries")
  resultEntries() {
    if (this.get("searching")) {
      return [];
    }
    return this.get("searchResultEntries") ?? [];
  }

  @discourseComputed("searchResultEntries")
  hasResults() {
    return this.get("searchResultEntries").length > 0;
  }

  resetSearch() {
    this.set("page", 0);
    this.set("searchResultEntries", []);
    this.set("searchResultEntriesCount", 0);
    this.set("loadingMore", false);
    this.set("noMoreResults", false);
  }

  @observes("search_type")
  triggerSearchOnTypeChange() {
    if (this.searchActivated) {
      this.resetSearch();
      this.search();
    }
  }

  @action
  search() {
    if (this.searchTerm.length < 2) {
      this.set("invalidSearch", true);
      return;
    }
    this.set("searchActivated", true);
    this.set("invalidSearch", false);
    this.resetSearch();
    this.set("searching", true);
    this.set("q", this.searchTerm);
    this._search().then((result) => {
      this.set(
        "searchResultEntries",
        Array.from(result.image_search_result.grouped_results)
      );
      this.set("noMoreResults", !result.image_search_result.has_more);
      this.set(
        "searchResultEntriesCount",
        this.get("searchResultEntries").length
      );
      this.set("searching", false);
    });
  }

  @action
  loadMore() {
    if (
      this.get("searching") ||
      this.get("loadingMore") ||
      this.get("noMoreResults")
    ) {
      return;
    }
    this.set("loadingMore", true);
    this.set("page", this.page + 1);
    this._search().then((result) => {
      this.set("noMoreResults", !result.image_search_result.has_more);
      if (result.image_search_result.grouped_results.length > 0) {
        this.set(
          "searchResultEntries",
          this.get("searchResultEntries").concat(
            result.image_search_result.grouped_results
          )
        );
        this.set(
          "searchResultEntriesCount",
          this.get("searchResultEntries").length
        );
      }
      this.set("loadingMore", false);
    });
  }
}
