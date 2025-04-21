# frozen_string_literal: true
class DiscourseImageEnhancement::ImageSearch
  class ImageSearchResultItem
    include ActiveModel::Serialization

    attr_reader :post, :user, :topic, :image, :optimized_images

    def initialize(post, user, topic, image, optimized_images)
      @post = post
      @user = user
      @topic = topic
      @image = image
      @optimized_images = optimized_images
    end
  end

  class ImageSearchResult
    include ActiveModel::Serialization

    attr_reader :search_ocr, :search_description, :search_embeddings, :term, :has_more

    def grouped_results
      @grouped_results ||=
        @posts
          .zip(@users, @topics, @images, @optimized_images)
          .map do |post, user, topic, image, optimized_images|
            ImageSearchResultItem.new(post, user, topic, image, optimized_images)
          end
    end

    def initialize(
      posts_id,
      uploads_id,
      term: nil,
      search_ocr: true,
      search_description: true,
      search_embeddings: true,
      page: 0,
      limit: nil,
      has_more: true
    )
      @term = term
      @search_ocr = search_ocr
      @search_description = search_description
      @page = page
      @limit = limit
      @has_more = has_more
      posts_id = [] if posts_id.nil?
      uploads_id = [] if uploads_id.nil?

      # result =
      #   result
      #     .select("posts.*,uploads.id as upload_id")
      #     .includes(topic: %i[tags category])
      #     .includes(:user)
      # uploads = Upload.where(id: result.map(&:upload_id)).includes(:optimized_images).group_by(&:id)
      posts = Post.where(id: posts_id).includes(topic: %i[tags category]).includes(:user)
      uploads = Upload.where(id: uploads_id).includes(:optimized_images).group_by(&:id)
      @posts = posts_id.map { |id| posts.find { |post| post.id == id } }
      @users = @posts.map(&:user)
      @topics = @posts.map(&:topic)
      @images = uploads_id.map { |id| uploads[id].first }
      @optimized_images = @images.map(&:optimized_images)
    end
  end
end
