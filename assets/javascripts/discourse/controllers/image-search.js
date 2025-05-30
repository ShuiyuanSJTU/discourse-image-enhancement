import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class extends Controller {
  searching = false;
  loadingMore = false;
  noMoreResults = false;
  searchActivated = false;
  invalidSearch = false;
  invalidSearchReason = "";
  searchTerm = "";
  searchImage = null;
  page = 0;
  searchResults = {};
  searchResultEntries = [];
  searchResultEntriesCount = 0;
  searchButtonDisabled = false;
  expandFilters = false;
  queryParams = ["q", "search_type"];
  q = undefined;
  q_image = undefined;

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
    {
      name: i18n("image_search.search_type.by_image"),
      id: "image_search_by_image",
    },
  ];

  search_type = this.searchTypes[0].id;

  constructor() {
    super(...arguments);
  }

  _search() {
    const searchType = this.get("search_type");
    if (searchType === "image_search_by_image") {
      const formData = new FormData();
      formData.append("image", this.get("q_image"));
      formData.append("page", this.get("page"));
      formData.append("term", this.get("q"));
      return ajax("/image-search/search.json", {
        type: "POST",
        processData: false,
        contentType: false,
        data: formData,
      });
    } else {
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
  }

  @discourseComputed("search_type")
  displaySearchTextField() {
    return this.get("search_type") !== "image_search_by_image";
  }

  @discourseComputed("search_type")
  displayImageUploader() {
    return this.get("search_type") === "image_search_by_image";
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

  resetSearchResult() {
    this.set("page", 0);
    this.set("searchResultEntries", []);
    this.set("searchResultEntriesCount", 0);
    this.set("loadingMore", false);
    this.set("noMoreResults", false);
    this.set("invalidSearch", false);
  }

  @action
  search() {
    if (this.get("search_type") === "image_search_by_image") {
      if (this.get("searchImage") === null) {
        this.set("invalidSearch", true);
        this.set("invalidSearchReason", i18n("image_search.invalid.no_image"));
        return;
      }
    } else {
      if (this.get("searchTerm").length < 2) {
        this.set("invalidSearch", true);
        this.set("invalidSearchReason", i18n("search.too_short"));
        return;
      }
    }
    this.set("searchActivated", true);
    this.set("invalidSearch", false);
    this.resetSearchResult();
    this.set("searching", true);
    this.set("q", this.searchTerm);
    this.set("q_image", this.searchImage);
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

  @action
  onSearchTypeChange(searchType) {
    const prevType = this.get("search_type");
    this.set("search_type", searchType);
    this.resetSearchResult();
    if (
      prevType === "image_search_by_image" ||
      searchType === "image_search_by_image"
    ) {
      // Cleanup image when switching from or to by image
      this.set("searchActivated", false);
      this.set("searchImage", null);
      this.set("q_image", null);
    } else {
      // Automatically trigger search when switching between text searchs
      if (this.get("searchActivated")) {
        this.search();
      }
    }
  }

  @action
  onFileSelected(file) {
    if (!file) {
      this.set("searchImage", null);
      return;
    }
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement("canvas");
        const ctx = canvas.getContext("2d");
        canvas.width = 224;
        canvas.height = 224;
        ctx.drawImage(img, 0, 0, 224, 224);

        canvas.toBlob((blob) => {
          this.set("searchImage", blob);
        }, "image/jpeg");
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
  }
}
