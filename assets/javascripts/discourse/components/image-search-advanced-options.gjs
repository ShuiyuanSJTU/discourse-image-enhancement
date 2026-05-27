import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import SearchAdvancedOptions from "discourse/components/search-advanced-options";
import discourseDebounce from "discourse/lib/debounce";
import Topic from "discourse/models/topic";
import ComboBox from "discourse/select-kit/components/combo-box";
import SearchAdvancedCategoryChooser from "discourse/select-kit/components/search-advanced-category-chooser";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import TopicChooser from "discourse/select-kit/components/topic-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DDateInput from "discourse/ui-kit/d-date-input";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const REGEXP_TOPIC_PREFIX = /^topic:/gi;

export default class ImageSearchAdvancedOptions extends SearchAdvancedOptions {
  constructor() {
    super(...arguments);
    this.setProperties({
      searchedTerms: {
        topic: null,
      },
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
      if (
        !isNaN(userInput) &&
        this.get("searchedTerms.topic")?.id !== userInput
      ) {
        discourseDebounce(this, this._fetchTopic, [userInput], 200);
        this.set("searchedTerms.topic", {
          id: userInput,
          title: `topic:${userInput}`,
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

  <template>
    <div
      class={{dConcatClass
        "advanced-filters"
        (if this.isExpanded "--is-expanded")
      }}
      ...attributes
    >
      <DButton
        class="advanced-filters__toggle btn-default"
        @ariaLabel={{i18n "search.advanced.title"}}
        @ariaExpanded={{this.isExpanded}}
        @action={{this.toggleFilters}}
      >
        {{#if this.submittedFilterCount}}
          <span class="badge-notification">{{this.submittedFilterCount}}</span>
        {{/if}}
        {{i18n "search.advanced.title"}}
        {{dIcon (if this.isExpanded "chevron-up" "chevron-down")}}
      </DButton>

      {{#if this.isExpanded}}
        <div class="search-advanced-filters">
          <div class="search-advanced-options">

            <div class="control-group advanced-search-category">
              <label class="control-label">{{i18n
                  "search.advanced.in_category.label"
                }}</label>
              <div class="controls">
                <SearchAdvancedCategoryChooser
                  @id="search-in-category"
                  @value={{this.searchedTerms.category.id}}
                />
              </div>
            </div>

            {{#if this.siteSettings.tagging_enabled}}
              <div class="control-group advanced-search-tags">
                <label class="control-label">{{i18n
                    "search.advanced.with_tags.label"
                  }}</label>
                <div class="controls">
                  <TagChooser
                    @id="search-with-tags"
                    @tags={{this.searchedTerms.tags}}
                    @everyTag={{true}}
                    @unlimitedTagCount={{true}}
                    @options={{hash
                      allowAny=false
                      headerAriaLabel=(i18n
                        "search.advanced.with_tags.aria_label"
                      )
                    }}
                  />
                </div>
              </div>
            {{/if}}

            <div class="control-group advanced-search-topic">
              <label class="control-label">
                {{i18n "search.advanced.in_topic.label"}}
              </label>
              <div class="controls">
                <TopicChooser
                  @id="search-in-topic"
                  @value={{this.searchedTerms.topic.id}}
                  @content={{array this.searchedTerms.topic}}
                  @onChange={{this.onChangeSearchTermForTopic}}
                />
              </div>
            </div>

            <div class="control-group advanced-search-posted-by">
              <label class="control-label">
                {{i18n "search.advanced.posted_by.label"}}
              </label>
              <div class="controls">
                <UserChooser
                  @id="search-posted-by"
                  @value={{this.searchedTerms.username}}
                  @options={{hash
                    headerAriaLabel=(i18n
                      "search.advanced.posted_by.aria_label"
                    )
                    maximum=1
                    excludeCurrentUser=false
                  }}
                />
              </div>
            </div>

            <div class="control-group advanced-search-posted-date">
              <label class="control-label">{{i18n
                  "search.advanced.post.time.label"
                }}</label>
              <div class="controls inline-form full-width">
                <ComboBox
                  @id="postTime"
                  @valueProperty="value"
                  @content={{this.postTimeOptions}}
                  @value={{this.searchedTerms.time.when}}
                  @options={{hash
                    headerAriaLabel=(i18n
                      "search.advanced.post.time.aria_label"
                    )
                  }}
                />
                <DDateInput
                  @date={{this.searchedTerms.time.days}}
                  @inputId="search-post-date"
                />
              </div>
            </div>

          </div>

          {{#if this.site.mobileView}}
            <div class="second-search-button">
              <DButton
                @action={{this.search}}
                @icon="magnifying-glass"
                @label="search.search_button"
                @ariaLabel="search.search_button"
                @disabled={{this.searchButtonDisabled}}
                class="btn-primary search-cta"
              />
            </div>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
