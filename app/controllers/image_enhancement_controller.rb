# frozen_string_literal: true
class ImageEnhancementController < ::ApplicationController
  SUPPORTED_IMAGE_SEARCH_TYPES = %w[jpeg jpg png webp].freeze

  requires_plugin ::DiscourseImageEnhancement::PLUGIN_NAME
  requires_login

  before_action :ensure_image_search_enabled
  before_action :rate_limit_image_search, only: :search

  def index
    render json: {}
  end

  def search
    if request.post?
      uploaded_image = params[:image]
      term = params[:term]
      validate_uploaded_image!(uploaded_image) if uploaded_image.present?
      # :image and :term should not be both blank
      raise Discourse::InvalidParameters.new(:image, :term) if uploaded_image.blank? && term.blank?
    else
      uploaded_image = nil
      term = params.require(:term)
    end
    if uploaded_image.present?
      ocr = false
      embeddings = false
    else
      ocr = params.fetch(:ocr, "true") == "true"
      embeddings = params.fetch(:embed, "true") == "true"
    end
    page = params.fetch(:page, 0).to_i
    saerch_results =
      ::DiscourseImageEnhancement::ImageSearch.new(
        term,
        uploaded_image,
        ocr: ocr,
        embeddings: embeddings,
        by_image: uploaded_image.present?,
        page: page,
        guardian: Guardian.new(current_user),
      ).execute
    render_serialized(saerch_results, ImageSearchResultSerializer)
  end

  private

  def ensure_image_search_enabled
    raise Discourse::NotFound if !SiteSetting.image_search_enabled
  end

  def rate_limit_image_search
    RateLimiter.new(
      current_user,
      "image-search",
      SiteSetting.rate_limit_search_user,
      1.minute,
    ).performed!
  end

  def validate_uploaded_image!(uploaded_image)
    if !uploaded_image.is_a?(ActionDispatch::Http::UploadedFile)
      raise Discourse::InvalidParameters.new(:image)
    end
    if !uploaded_image.content_type&.start_with?("image/")
      raise Discourse::InvalidParameters.new(:image)
    end

    tempfile = uploaded_image.tempfile
    raise Discourse::InvalidParameters.new(:image) if tempfile.blank? || tempfile.path.blank?

    filesize = uploaded_image.size.to_i
    max_filesize = SiteSetting.image_enhancement_max_image_size_kb.kilobytes
    raise Discourse::InvalidParameters.new(:image) if filesize <= 0 || filesize > max_filesize

    image = FastImage.new(tempfile.path, raise_on_failure: true)
    image_type = image.type.to_s
    width, height = image.size

    if image_type.blank? || width.blank? || height.blank? ||
         SUPPORTED_IMAGE_SEARCH_TYPES.exclude?(image_type) ||
         width < SiteSetting.image_enhancement_min_image_width ||
         height < SiteSetting.image_enhancement_min_image_height
      raise Discourse::InvalidParameters.new(:image)
    end
  rescue FastImage::UnknownImageType, FastImage::SizeNotFound
    raise Discourse::InvalidParameters.new(:image)
  end
end
