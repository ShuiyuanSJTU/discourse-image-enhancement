# frozen_string_literal: true

require_relative "image_search_result_item_serializer"

class ImageSearchResultSerializer < ApplicationSerializer
  attributes :term,
             :processed_term,
             :search_ocr,
             :search_embeddings,
             :search_by_image,
             :grouped_results,
             :has_more
  def grouped_results
    object.grouped_results.map do |result|
      ImageSearchResultItemSerializer.new(result, scope: scope, root: false).as_json
    end
  end
end
