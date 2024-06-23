require_relative "image_search/image_search_result"

module ::DiscourseImageEnhancement
  class ImageSearch
    
    def initialize(term, 
        limit: 20, page: 0,
        ocr: true, description: true, 
        guardian: nil)
      @term = term
      @limit = limit
      @page = page
      @ocr = ocr
      @description = description
      @has_more = true
      @guardian = guardian || Guardian.new
    end

    def search_images(term = nil)
      term ||= @term
      return nil if term.blank? || (!@ocr && !@description)
      ts_config = Search.ts_config
      # user input will be quoted after to_tsquery, we can safely interpolate it
      @safe_term_tsquery = Search.ts_query(term: Search.prepare_data(term, :query),ts_config: Search.ts_config)

      images = Upload.joins("JOIN image_search_data ON COALESCE(uploads.original_sha1, uploads.sha1) = image_search_data.sha1")

      conditions = []
      parameters = []

      if @ocr
        conditions << "ocr_text_search_data @@ #{@safe_term_tsquery}"
      end

      if @description
        conditions << "description_search_data @@ #{@safe_term_tsquery}"
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
        posts = posts.joins(:uploads)
          .joins("JOIN image_search_data ON COALESCE(uploads.original_sha1, uploads.sha1) = image_search_data.sha1")
          .order(<<-SQL.squish)
          (ts_rank_cd(ocr_text_search_data, #{@safe_term_tsquery}), posts.created_at) DESC
        SQL
      elsif @description
        posts = posts.joins(:uploads)
          .joins("JOIN image_search_data ON COALESCE(uploads.original_sha1, uploads.sha1) = image_search_data.sha1")
          .order(<<-SQL.squish)
          (ts_rank_cd(description_search_data, #{@safe_term_tsquery}), posts.created_at) DESC
        SQL
      end
      posts
    end

    def execute
      term = process_advanced_search!(@term)

      posts = filter_post(Post)
      posts = apply_advanced_filters(posts)

      search_reslut_images = search_images(term)
      posts = posts.joins(:uploads).where(
        uploads: { id: search_reslut_images }
      )
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

    def self.advanced_filter(trigger, &block)
      advanced_filters[trigger] = block
    end
  
    def self.advanced_filters
      @advanced_filters ||= {}
    end

    def process_advanced_search!(term)
      term
        .to_s
        .scan(/(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/)
        .to_a
        .map do |(word, _)|
          next if word.blank?
  
          found = false
  
          ImageSearch.advanced_filters.each do |matcher, block|
            cleaned = word.gsub(/["']/, "")
            if cleaned =~ matcher
              (@filters ||= []) << [block, $1]
              found = true
            end
          end

          found ? nil : word
        end
        .compact
        .join(" ")
    end

    def apply_advanced_filters(posts)
      @filters.each do |block, match|
        if block.arity == 1
          posts = instance_exec(posts, &block) || posts
        else
          posts = instance_exec(posts, match, &block) || posts
        end
      end if @filters
      posts
    end

    advanced_filter(/\Atopic:(\d+)\z/i) do |posts, match|
      posts.where(topic_id: match.to_i)
    end

    advanced_filter(/\Abefore:(.*)\z/i) do |posts, match|
      if date = Search.word_to_date(match)
        posts.where("posts.created_at < ?", date)
      else
        posts
      end
    end
  
    advanced_filter(/\Aafter:(.*)\z/i) do |posts, match|
      if date = Search.word_to_date(match)
        posts.where("posts.created_at > ?", date)
      else
        posts
      end
    end

    advanced_filter(/\A\@(\S+)\z/i) do |posts, match|
      username = User.normalize_username(match)
  
      user_id = User.not_staged.where(username_lower: username).pick(:id)
  
      user_id = @guardian.user&.id if !user_id && username == "me"
  
      if user_id
        posts.where("posts.user_id = ?", user_id)
      else
        posts.none
      end
    end

    advanced_filter(/\Atags:(\S+)\z/i) do |posts, match|
      tag_names = match.split(",")
      tags = Tag.where(name: tag_names)
      posts.where(
        id: Post.joins({ topic: :tags }).where(tags: { id: tags })
      )
    end

    advanced_filter(/\A\#([\p{L}\p{M}0-9\-:=]+)\z/i) do |posts, match|
      category_slug, subcategory_slug = match.to_s.split(":")
      next unless category_slug

      exact = true
      if category_slug[0] == "="
        category_slug = category_slug[1..-1]
      else
        exact = false
      end

      category_id =
        if subcategory_slug
          Category
            .where("lower(slug) = ?", subcategory_slug.downcase)
            .where(
              parent_category_id:
                Category.where("lower(slug) = ?", category_slug.downcase).select(:id),
            )
            .pick(:id)
        else
          Category
            .where("lower(slug) = ?", category_slug.downcase)
            .order("case when parent_category_id is null then 0 else 1 end")
            .pick(:id)
        end

      if category_id
        category_ids = [category_id]
        category_ids += Category.subcategory_ids(category_id) if !exact

        posts.joins(:topic)
          .where({ topics: { category_id: category_ids } })
      else
        posts.none
      end
    end
  end
end