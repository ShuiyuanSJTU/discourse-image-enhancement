# frozen_string_literal: true

require_relative "image_search_result_topic_serializer"
require_relative "image_search_result_post_serializer"

class ImageSearchResultItemSerializer < ApplicationSerializer
  attributes :image, :optimized_images, :link_target
  attributes :post, :user, :topic

  def post
    ImageSearchResultPostSerializer.new(object.post, scope: scope, root: false).as_json
  end

  def user
    PosterSerializer.new(object.user, scope: scope, root: false).as_json
  end

  def topic
    ImageSearchResultTopicSerializer.new(object.topic, scope: scope, root: false).as_json
  end

  def image
    {
      url: UrlHelper.cook_url(object.image.url, secure: object.image.secure),
      width: object.image.width,
      height: object.image.height
    }
  end

  def optimized_images
    object.optimized_images.map do |optimized_image|
      {
        # we cannot direct check if optimized_image is secured or not, so check the original image
        url: UrlHelper.cook_url(optimized_image.url, secure: object.image.secure),
        width: optimized_image.width,
        height: optimized_image.height
      }
    end
  end
  
  def link_target
    object.post.url
  end
end