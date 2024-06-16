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

    attr_reader :search_ocr, :search_description, :term

    def grouped_results
      @grouped_results ||= @posts.zip(@users, @topics, @images, @optimized_images).map do |post, user, topic, image, optimized_images|
        ImageSearchResultItem.new(post, user, topic, image, optimized_images)
      end
    end

    def has_more
      @has_more ||= begin
        return false if @posts.length == 0
        return false if @limit.present? && @posts.length < @limit
        true
      end
    end

    def initialize(result,
        term: nil, search_ocr: true, search_description: true,
        page: 0, limit: nil)
      @term = term
      @search_ocr = search_ocr
      @search_description = search_description
      @page = page
      @limit = limit

      result = result.select("posts.*,uploads.id as upload_id").includes(topic: [:tags, :category]).includes(:user)
      @posts = result
      @users = @posts.map(&:user)
      @topics = @posts.map(&:topic)
      uploads = Upload.where(id: result.map(&:upload_id)).includes(:optimized_images).group_by(&:id)
      @images = result.map(&:upload_id).map { |id| uploads[id].first }
      @optimized_images = @images.map(&:optimized_images)
    end
  end
end