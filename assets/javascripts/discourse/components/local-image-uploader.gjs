import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { modifier } from "ember-modifier";
import $ from "jquery";
import DButton from "discourse/components/d-button";
import PickFilesButton from "discourse/components/pick-files-button";
import icon from "discourse/helpers/d-icon";
import lightbox from "discourse/lib/lightbox";
import { bindFileInputChangeListener } from "discourse/lib/uploads";
import { i18n } from "discourse-i18n";

// Args: id, imageUrl, placeholderUrl, onFileSelected, onFileDeleted, disabled
export default class LocalImageUploader extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked imagePreviewUrl;
  @tracked imageFilename;
  @tracked imageWidth;
  @tracked imageHeight;

  applyLightbox = modifier(() => {
    if (this.imagePreviewUrl) {
      lightbox(
        document.querySelector(`#${this.args.id}.image-uploader`),
        this.siteSettings
      );
    }
  });

  willDestroy() {
    super.willDestroy(...arguments);
    $.magnificPopup?.instance.close();
  }

  get disabled() {
    return this.args.disabled;
  }

  get showingPlaceholder() {
    return !this.imagePreviewUrl && this.args.placeholderUrl;
  }

  get placeholderStyle() {
    if (isEmpty(this.args.placeholderUrl)) {
      return htmlSafe("");
    }
    return htmlSafe(`background-image: url(${this.args.placeholderUrl})`);
  }

  get backgroundStyle() {
    return htmlSafe(
      `background-image: url(${
        this.imagePreviewUrl || this.args.placeholderUrl
      })`
    );
  }

  @action
  setupFileInput(elem) {
    bindFileInputChangeListener(elem, this.handleSelectedFile);
  }

  @action
  handleSelectedFile(file) {
    if (file) {
      this.imagePreviewUrl = URL.createObjectURL(file);
      this.imageFilename = file.name;
      const img = new Image();
      img.onload = () => {
        this.imageWidth = img.naturalWidth;
        this.imageHeight = img.naturalHeight;
      };
      img.src = this.imagePreviewUrl;

      this.args.onFileSelected(file);
    }
  }

  @action
  handleDeletedFile() {
    this.imagePreviewUrl = null;
    this.imageFilename = null;
    this.imageWidth = null;
    this.imageHeight = null;

    this.args.onFileDeleted();
  }

  @action
  toggleLightbox() {
    const lightboxElement = document.querySelector(
      `#${this.args.id} a.lightbox`
    );

    if (lightboxElement) {
      $(lightboxElement).magnificPopup("open");
    }
  }

  @action
  handleKeyboardActivation(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault(); // avoid space scrolling the page
      const input = document.getElementById(this.computedId);
      if (input && !this.disabled) {
        input.click();
      }
    }
  }

  @action
  handleFileDrop(event) {
    event.preventDefault();
    const file = event.dataTransfer.files[0];
    if (file) {
      this.handleSelectedFile(file);
    }
  }

  @action
  preventDefault(event) {
    event.preventDefault();
  }

  <template>
    <div
      id={{@id}}
      class="image-uploader {{if this.imagePreviewUrl 'has-image' 'no-image'}}"
      ...attributes
      {{on "dragover" this.preventDefault}}
      {{on "drop" this.handleFileDrop}}
    >
      <div
        class="uploaded-image-preview input-xxlarge"
        style={{this.backgroundStyle}}
      >
        {{#if this.showingPlaceholder}}
          <div
            class="placeholder-overlay"
            style={{this.placeholderStyle}}
          ></div>
        {{/if}}

        {{#if this.imagePreviewUrl}}
          <a
            {{this.applyLightbox}}
            href={{this.imagePreviewUrl}}
            title={{this.imageFilename}}
            rel="nofollow ugc noopener"
            class="lightbox"
          >
            <div class="meta">
              <span class="informations">
                {{this.imageWidth}}x{{this.imageHeight}}
              </span>
            </div>
          </a>

          <div class="expand-overlay">
            <DButton
              @action={{this.toggleLightbox}}
              @icon="discourse-expand"
              @title="expand"
              class="btn-default btn-small image-uploader-lightbox-btn"
            />
            <DButton
              @action={{this.handleDeletedFile}}
              @icon="trash-can"
              class="btn-danger btn-small"
            />
          </div>
        {{else}}
          <div class="image-upload-controls">
            <label
              class="btn btn-default btn-small btn-transparent
                {{if this.disabled 'disabled'}}"
              title={{this.disabledReason}}
              tabindex="0"
              {{on "keydown" this.handleKeyboardActivation}}
            >
              {{icon "upload"}}
              <PickFilesButton
                @fileInputId={{@id}}
                @fileInputDisabled={{this.disabled}}
                @acceptedFormatsOverride="image/*"
                @registerFileInput={{this.setupFileInput}}
              />
              {{i18n "upload_selector.select_file"}}
            </label>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
