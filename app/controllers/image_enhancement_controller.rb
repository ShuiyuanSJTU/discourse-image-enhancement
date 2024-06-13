# # frozen_string_literal: true

module ::DiscourseImageEnhancement
  class ImageEnhancementController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      render json: { hello: "world" }
    end

    def search
      term = params.require(:term)
      ocr = params.fetch(:ocr, 'true') == 'true'
      description = params.fetch(:description, 'true') == 'true'
      saerch_results = ImageSearch.new(term, ocr: ocr, description: description).execute
      render_serialized(saerch_results, ImageSearchResultSerializer)
    end
  end
end
