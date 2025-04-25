# frozen_string_literal: true
# # frozen_string_literal: true

class ImageEnhancementController < ::ApplicationController
  requires_plugin ::DiscourseImageEnhancement::PLUGIN_NAME

  def index
    render json: {}
  end

  def search
    if request.post?
      uploaded_image = params[:image]
      term = params[:term]
      if !uploaded_image.blank? &&
           !(
             uploaded_image.is_a?(ActionDispatch::Http::UploadedFile) &&
               uploaded_image.content_type.start_with?("image/")
           )
        raise Discourse::InvalidParameters.new(:image)
      end
      # :image and :term should not be both blank
      raise Discourse::InvalidParameters.new(:image, :term) if uploaded_image.blank? && term.blank?
    else
      uploaded_image = nil
      term = params.require(:term)
    end
    ocr = params.fetch(:ocr, "true") == "true"
    embeddings = params.fetch(:embed, "true") == "true"
    page = params.fetch(:page, 0).to_i
    saerch_results =
      ::DiscourseImageEnhancement::ImageSearch.new(
        term,
        uploaded_image,
        ocr: ocr,
        embeddings: embeddings,
        page: page,
        guardian: Guardian.new(current_user),
      ).execute
    render_serialized(saerch_results, ImageSearchResultSerializer)
  end
end
