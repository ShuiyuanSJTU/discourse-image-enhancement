import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Topic from "discourse/models/topic";

export default class extends Component{
  @service router;
  constructor() {
    super(...arguments);
    this.topic = Topic.create(this.args.resultEntry.topic);
    this.post = this.args.resultEntry.post;
  }
  get imageSrc() {
    const optimizedImage = this.args.resultEntry.image.optimized_image;
    if (optimizedImage) {
      const choosedOptimizedImage = optimizedImage.filter(
        image => image.height > 300 && image.width > 150
      ).reduce(
        (prev, current) =>
          (prev.height * prev.width < current.height * current.width) ? prev : current
      );
      if (choosedOptimizedImage) {
        return choosedOptimizedImage.url;
      }
    }
    return this.args.resultEntry.image.url;
  }
  get postContent() {
    let parser = new DOMParser();
    let doc = parser.parseFromString(this.post.cooked, "text/html");
    let textContent = doc.body.textContent;
    return textContent;
  }

  @action
  goToPath(event) {
    event.preventDefault();
    this.router.transitionTo(this.args.resultEntry.link_target);
    return false;
  }
}