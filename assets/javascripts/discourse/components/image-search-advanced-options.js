import { action } from "@ember/object";
import SearchAdvancedOptions from "discourse/components/search-advanced-options";
import Topic from "discourse/models/topic";
import discourseDebounce from "discourse-common/lib/debounce";

const REGEXP_TOPIC_PREFIX = /^topic:/gi;

export default class ImageSearchAdvancedOptions extends SearchAdvancedOptions {
  constructor() {
    super(...arguments);
    this.setProperties({
      searchedTerms: {
        topic: null,
      }
    });
  }

  didReceiveAttrs() {
    super.didReceiveAttrs();
    this.setSearchedTermValueForTopic();
  }

  setSearchedTermValueForTopic() {
    const match = this.filterBlocks(REGEXP_TOPIC_PREFIX);
    if (match.length > 0) {
      const userInput = parseInt(match[0].replace(REGEXP_TOPIC_PREFIX, ""), 10);
      if(!isNaN(userInput) && this.get("searchedTerms.topic")?.id !== userInput){
        discourseDebounce(this, this._fetchTopic, [userInput], 200);
        this.set("searchedTerms.topic", {
          id: userInput,
          title: `topic:${userInput}`
        });
      }
    }
  }

  _fetchTopic(topicId) {
    if (!topicId || this.get("searchedTerms.topic")?.id === topicId) {
      return;
    }
    Topic.find(topicId, {}).then((topic) => {
      this.set("searchedTerms.topic", topic);
    });
  }

  _updateSearchTermForTopic() {
    const match = this.filterBlocks(REGEXP_TOPIC_PREFIX);
    const topicFilter = this.get("searchedTerms.topic")?.id;
    let searchTerm = this.searchTerm || "";

    if (topicFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `topic:${topicFilter}`);
      } else {
        searchTerm += ` topic:${topicFilter}`;
      }
    } else {
      searchTerm = searchTerm.replace(match[0], "");
    }
    this._updateSearchTerm(searchTerm);
  }

  @action
  onChangeSearchTermForTopic(topicId, topic) {
    this.set("searchedTerms.topic", topic);
    this._updateSearchTermForTopic();
  }
}