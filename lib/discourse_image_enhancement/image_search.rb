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

      conditions = []
      parameters = []

      if @ocr
        conditions << "ocr_text_search_data @@ #{safe_term_tsquery}"
      end

      if @description
        conditions << "description_search_data @@ #{safe_term_tsquery}"
      end

      if conditions.any?
        images = ImageSearchData.where(conditions.join(' OR '))
        images = images.joins("LEFT JOIN uploads ON (image_search_data.sha1 = uploads.sha1 OR image_search_data.sha1 = uploads.original_sha1)")
        if @ocr && @description
          images = images.order("uploads.created_at": :desc)
        elsif @ocr
          images = images.order(<<-SQL.squish)
            (ts_rank_cd(ocr_text_search_data, #{safe_term_tsquery}), uploads.created_at) DESC
          SQL
        elsif @description
          images = images.order(<<-SQL.squish)
            (ts_rank_cd(description_search_data, #{safe_term_tsquery}), uploads.created_at) DESC
          SQL
        end
      end

      sha1 = images.offset(@page * @limit).limit(@limit).pluck(:sha1)

      @has_more = sha1.length == @limit

      Upload.where(original_sha1: sha1).or(Upload.where(sha1: sha1, original_sha1: nil))
    end

    def execute
      uploads = search_images
      posts = Post.joins(:uploads).merge(uploads)
      posts = filter_post(posts).order("posts.created_at DESC")
      ImageSearchResult.new(posts, 
        term: @term, 
        search_ocr: @ocr, 
        search_description: @description, 
        has_more: @has_more)
    end

    def filter_post(posts)
      self.class.filter_post(posts)
    end

    def self.filter_post(posts)
      Filter.filter_post(posts)
    end
  end
end