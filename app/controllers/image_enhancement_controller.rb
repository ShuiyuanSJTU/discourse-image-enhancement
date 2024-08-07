# frozen_string_literal: true
# # frozen_string_literal: true

class ImageEnhancementController < ::ApplicationController
  requires_plugin ::DiscourseImageEnhancement::PLUGIN_NAME

  def index
    render json: {}
  end

  def search
    term = params.require(:term)
    ocr = params.fetch(:ocr, "true") == "true"
    description = params.fetch(:description, "true") == "true"
    page = params.fetch(:page, 0).to_i
    saerch_results =
      ::DiscourseImageEnhancement::ImageSearch.new(
        term,
        ocr: ocr,
        description: description,
        page: page,
        guardian: Guardian.new(current_user),
      ).execute
    render_serialized(saerch_results, ImageSearchResultSerializer)
  end
end
