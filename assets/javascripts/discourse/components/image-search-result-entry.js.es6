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
    //TODO: optimized image
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