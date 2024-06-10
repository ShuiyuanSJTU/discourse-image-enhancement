import Component from "@ember/component";
import { categoryBadgeHTML } from "discourse/helpers/category-link";

export default Component.extend({
  tagName: "",
  get imageSrc() {
    return "https://s3.jcloud.sjtu.edu.cn:443/shuiyuan/static/test-static/11.jpg";
  },
});