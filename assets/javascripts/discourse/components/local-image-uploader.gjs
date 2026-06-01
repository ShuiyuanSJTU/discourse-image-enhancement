import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { modifier } from "ember-modifier";
import lightbox from "discourse/lib/lightbox";
import { bindFileInputChangeListener } from "discourse/lib/uploads";
import DButton from "discourse/ui-kit/d-button";
import DPickFilesButton from "discourse/ui-kit/d-pick-files-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

let localImageUploaderId = 0;

// Args: id, imageUrl, placeholderUrl, onFileSelected, onFileDeleted, disabled
export default class LocalImageUploader extends Component {
  @service siteSettings;

  @tracked imagePreviewUrl;
  @tracked imageFilename;
  @tracked imageWidth;
  @tracked imageHeight;

  fallbackInputId = `local-image-uploader-${localImageUploaderId++}__input`;

  applyLightbox = modifier((element) => {
    if (this.imagePreviewUrl) {
      lightbox(element.closest(".file-uploader"), this.siteSettings);
    }
  });

  willDestroy() {
    super.willDestroy(...arguments);
    window.pswp?.close();
    if (this.imagePreviewUrl) {
      URL.revokeObjectURL(this.imagePreviewUrl);
    }
  }

  get disabled() {
    return this.args.disabled;
  }

  get computedId() {
    return this.args.id ? `${this.args.id}__input` : this.fallbackInputId;
  }

  get showingPlaceholder() {
    return !this.imagePreviewUrl && this.args.placeholderUrl;
  }

  get placeholderStyle() {
    if (isEmpty(this.args.placeholderUrl)) {
      return trustHTML("");
    }
    return trustHTML(`background-image: url(${this.args.placeholderUrl})`);
  }

  get backgroundStyle() {
    if (isEmpty(this.imagePreviewUrl) && isEmpty(this.args.placeholderUrl)) {
      return trustHTML("");
    }
    return trustHTML(
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
    if (file && file.type.startsWith("image/")) {
      if (this.imagePreviewUrl) {
        URL.revokeObjectURL(this.imagePreviewUrl);
      }

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
    if (this.imagePreviewUrl) {
      URL.revokeObjectURL(this.imagePreviewUrl);
    }

    this.imagePreviewUrl = null;
    this.imageFilename = null;
    this.imageWidth = null;
    this.imageHeight = null;

    this.args.onFileDeleted();
  }

  @action
  async toggleLightbox() {
    const lightboxElement = document.querySelector(
      `#${this.args.id} a.lightbox`
    );

    if (lightboxElement) {
      await lightbox(
        lightboxElement.closest(".file-uploader"),
        this.siteSettings
      );
      lightboxElement.click();
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
      class="file-uploader {{if this.imagePreviewUrl 'has-image' 'no-image'}}"
      ...attributes
      {{on "dragover" this.preventDefault}}
      {{on "drop" this.handleFileDrop}}
    >
      <div
        class="file-uploader__preview input-xxlarge"
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
          <div class="file-uploader__controls">
            <label
              class="btn btn-transparent {{if this.disabled 'disabled'}}"
              title={{this.disabledReason}}
              for={{this.computedId}}
              tabindex="0"
              {{on "keydown" this.handleKeyboardActivation}}
            >
              {{dIcon "upload"}}
              <DPickFilesButton
                @fileInputId={{this.computedId}}
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
