# frozen_string_literal: true

class ImageSearchResultPostSerializer < BasicPostSerializer
  attributes :post_number

  def post_number
    object.post_number
  end
end