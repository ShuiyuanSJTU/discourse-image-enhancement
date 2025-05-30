import { fn, hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import SearchTextField from "discourse/components/search-text-field";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import ImageSearchAdvancedOptions from "../components/image-search-advanced-options";
import ImageSearchResultEntries from "../components/image-search-result-entries";
import LocalImageUploader from "../components/local-image-uploader";

export default RouteTemplate(
  <template>
    <section class="search-container image-search-container">
      <div class="search-header image-search-header" role="search">
        <h1 class="search-page-heading">
          {{i18n "image_search.title"}}
        </h1>
        <p> {{i18n "image_search.description"}} </p>
        <div class="search-bar">
          {{#if @controller.displaySearchTextField}}
            <SearchTextField
              @value={{@controller.searchTerm}}
              @aria-label={{i18n "search.search_term_label"}}
              @enter={{@controller.search}}
              @aria-controls="search-result-count"
              class="full-page-search search no-blur search-query"
            />
          {{/if}}
          {{#if @controller.displayImageUploader}}
            <LocalImageUploader
              @id="search-image-uploader"
              @onFileSelected={{@controller.onFileSelected}}
              @onFileDeleted={{@controller.onFileSelected}}
              class="full-page-search search search-by-image"
            />
          {{/if}}
          <ComboBox
            @id="search-type"
            @value={{@controller.search_type}}
            @content={{@controller.searchTypes}}
            @onChange={{@controller.onSearchTypeChange}}
            @options={{hash castInteger=true}}
          />
          <DButton
            @action={{@controller.search}}
            @icon="magnifying-glass"
            @label="search.search_button"
            @ariaLabel="search.search_button"
            @disabled={{@controller.searchButtonDisabled}}
            class="btn-primary search-cta"
          />
        </div>

        <div class="search-filters">
          <ImageSearchAdvancedOptions
            @searchTerm={{readonly @controller.searchTerm}}
            @onChangeSearchTerm={{fn (mut @controller.searchTerm)}}
            @search={{@controller.search}}
            @searchButtonDisabled={{@controller.searchButtonDisabled}}
            @expandFilters={{@controller.expandFilters}}
          />
        </div>

        <div class="search-notice">
          {{#if @controller.invalidSearch}}
            <div class="fps-invalid">
              {{@controller.invalidSearchReason}}
            </div>
          {{/if}}
        </div>

        {{#if @controller.searching}}
          {{loadingSpinner size="medium"}}
        {{else}}
        {{/if}}
      </div>

      {{#unless (or @controller.hasResults @controller.searching)}}
        {{#if @controller.searchActivated}}
          <h3 class="image-search-no-results">{{i18n "search.no_results"}}</h3>
        {{/if}}
      {{/unless}}

      {{#if @controller.hasResults}}
        <LoadMore
          @selector=".img-search-result-entry"
          @action={{@controller.loadMore}}
        >
          <ImageSearchResultEntries
            @resultEntries={{@controller.resultEntries}}
          />
          {{#if @controller.loadingMore}}
            {{loadingSpinner size="medium"}}
          {{/if}}
          {{#if @controller.noMoreResults}}
            <div class="no-more-results">{{i18n "search.no_more_results"}}</div>
          {{/if}}
        </LoadMore>
      {{/if}}
    </section>
  </template>
);
