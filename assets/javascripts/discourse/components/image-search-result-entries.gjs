import Component from "@glimmer/component";
import ImageSearchResultEntry from "./image-search-result-entry";

export default class extends Component {
  tagName = "";

  <template>
    <div class="img-search-result-entries" role="list">
      <table class="topic-list topic-thumbnails-grid">
        <tbody class="topic-list-body">
          {{#each @resultEntries as |resultEntry|}}
            <ImageSearchResultEntry @resultEntry={{resultEntry}} />
          {{/each}}
        </tbody>
      </table>
    </div>
  </template>
}
