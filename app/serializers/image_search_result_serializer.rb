# frozen_string_literal: true

require_relative "image_search_result_item_serializer"

class ImageSearchResultSerializer < ApplicationSerializer
  # has_many :grouped_results, serializer: ImageSearchResultItemSerializer
  attributes :term, :search_ocr, :search_description, :grouped_results
  def grouped_results
    object.grouped_results.map do |result|
      ImageSearchResultItemSerializer.new(result, scope: scope, root: false).as_json
    end
  end
end