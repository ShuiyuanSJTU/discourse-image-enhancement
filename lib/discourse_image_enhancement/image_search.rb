require_relative "image_search/image_search_result"

module ::DiscourseImageEnhancement
  class ImageSearch
    
    def initialize(term, limit: 20, ocr: true, description: true, page: 0)
      @term = term
      @limit = limit
      @page = page
      @ocr = ocr
      @description = description
      @has_more = true
    end

    def search_images
      return nil if @term.blank? || (!@ocr && !@description)
      ts_config = Search.ts_config
      # user input will be quoted after to_tsquery, we can safely interpolate it
      safe_term_tsquery = Search.ts_query(term: Search.prepare_data(@term, :query),ts_config: Search.ts_config)

      images = Upload.joins("JOIN image_search_data ON COALESCE(uploads.original_sha1, uploads.sha1) = image_search_data.sha1")

      conditions = []
      parameters = []

      if @ocr
        conditions << "ocr_text_search_data @@ #{safe_term_tsquery}"
      end

      if @description
        conditions << "description_search_data @@ #{safe_term_tsquery}"
      end

      if conditions.any?
        images = images.where(conditions.join(' OR '))
      end

      images
    end

    def order_result(posts)
      if @ocr && @description
        posts = posts.order("posts.created_at": :desc)
      elsif @ocr
        posts = posts.order(<<-SQL.squish)
          (ts_rank_cd(ocr_text_search_data, #{safe_term_tsquery}), posts.created_at) DESC
        SQL
      elsif @description
        posts = posts.order(<<-SQL.squish)
          (ts_rank_cd(description_search_data, #{safe_term_tsquery}), posts.created_at) DESC
        SQL
      end
      posts
    end

    def execute
      posts = filter_post(Post).joins(:uploads)
      search_reslut_images = search_images
      posts = posts.where(uploads: { id: search_reslut_images })
      posts = order_result(posts)
      posts = posts.offset(@page * @limit).limit(@limit)

      ImageSearchResult.new(posts, 
        term: @term, 
        search_ocr: @ocr, 
        search_description: @description, 
        page: @page,
        limit: @limit)
    end

    def filter_post(posts)
      self.class.filter_post(posts)
    end

    def self.filter_post(posts)
      Filter.filter_post(posts)
    end
  end
end