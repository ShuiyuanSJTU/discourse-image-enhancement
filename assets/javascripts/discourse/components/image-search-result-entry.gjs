import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import avatar from "discourse/helpers/avatar";
import categoryLink from "discourse/helpers/category-link";
import discourseTags from "discourse/helpers/discourse-tags";
import formatDate from "discourse/helpers/format-date";
import Topic from "discourse/models/topic";

export default class extends Component {
  @service router;

  constructor() {
    super(...arguments);
    this.topic = Topic.create(this.args.resultEntry.topic);
    this.post = this.args.resultEntry.post;
  }

  get imageSrc() {
    const optimizedImages = this.args.resultEntry.optimized_images;
    if (optimizedImages) {
      let chosenOptimizedImage = optimizedImages.filter(
        (image) => image.height > 300 && image.width > 150
      );
      if (chosenOptimizedImage?.length > 0) {
        chosenOptimizedImage = chosenOptimizedImage.reduce((prev, current) =>
          prev.height * prev.width < current.height * current.width
            ? prev
            : current
        );
        return chosenOptimizedImage.url;
      }
    }
    return this.args.resultEntry.image.url;
  }

  get postContent() {
    let parser = new DOMParser();
    let doc = parser.parseFromString(this.post.cooked, "text/html");
    doc
      .querySelectorAll(".lightbox-wrapper")
      .forEach((wrapper) => wrapper.remove());
    doc.querySelectorAll(".onebox").forEach((onebox) => onebox.remove());
    let textContent = doc.body.textContent;
    if (this.post.post_number > 1) {
      textContent = `#${this.post.post_number} ${textContent}`;
    }
    return textContent;
  }

  @action
  goToPath(event) {
    event.preventDefault();
    this.router.transitionTo(this.args.resultEntry.link_target);
    return false;
  }

  <template>
    <tr class="img-search-result-entry topic-list-item" role="list">
      <td class="img-search-img">
        <div class="img-thumbnail">
          <a href={{@resultEntry.link_target}}>
            <img
              class="background-thumbnail"
              src={{this.imageSrc}}
              srcset={{this.imageSrcSet}}
              alt={{@resultEntry.text}}
            />
            <img
              class="main-thumbnail"
              src={{this.imageSrc}}
              srcset={{this.imageSrcSet}}
              alt={{@resultEntry.text}}
            />
          </a>
        </div>
      </td>
      <td class="img-search-activity">
        <span class="date">
          {{formatDate this.post.created_at format="tiny"}}
        </span>
      </td>
      <td class="img-search-topic-title topic-list-data main-link">
        <span class="link-top-line">
          <a
            href={{@resultEntry.link_target}}
            class="title raw-link raw-topic-link"
            role="heading"
            aria-level="2"
            {{on "click" this.goToPath}}
          >
            {{this.topic.fancy_title}}
          </a>
        </span>
        <div class="link-bottom-line">
          {{categoryLink this.topic.category}}
          {{discourseTags this.topic mode="list" tagsForUser=this.tagsForUser}}
        </div>
      </td>
      <td class="img-search-post">
        <span class="topic-excerpt post-excerpt">
          {{this.postContent}}
        </span>
      </td>
      <td class="img-search-posters">
        <div class="author">
          <a href={{this.post.userPath}} data-user-card={{this.post.username}}>
            {{avatar this.post imageSize="30px"}}
          </a>
        </div>
      </td>
    </tr>
  </template>
}
