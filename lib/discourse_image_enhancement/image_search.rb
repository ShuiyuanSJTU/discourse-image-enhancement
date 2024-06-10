module ::DiscourseImageEnhancement
  class ImageSearch
    
    def initialize(term, limit: 10, ocr: true, description: true)
      @term = term
      @limit = limit
      @ocr = ocr
      @description = description
    end

    def search_images
      return nil if @term.blank? || (!@ocr && !@description)
      term = Search.prepare_data(@term, :query)
      ts_config = Search.ts_config
      conditions = []
      parameters = []

      if ocr
        conditions << "ocr_text_search_data @@ to_tsquery(?, ?)"
        parameters += [ts_config, @term]
      end

      if @description
        conditions << "description_search_data @@ to_tsquery(?, ?)"
        parameters += [ts_config, @term]
      end

      if @conditions.any?
        images = ImageSearchData.where(conditions.join(' OR '), *parameters)
        if @ocr && @description
          images = images.order("ts_rank_cd(#{ts_config}, ocr_text_search_data, to_tsquery(?, ?)) * 1.5 + ts_rank_cd(#{ts_config}, description_search_data, to_tsquery(?, ?)) DESC", ts_config, @term, ts_config, @term)
        elsif ocr
          images = images.order("ts_rank_cd(#{ts_config}, ocr_text_search_data, to_tsquery(?, ?)) DESC", ts_config, @term)
        elsif description
          images = images.order("ts_rank_cd(#{ts_config}, description_search_data, to_tsquery(?, ?)) DESC", ts_config, @term)
        end
      end

      sha1 = images.limit(limit).pluck(:sha1)
      
      Upload.where(original_sha1: sha1).or(Upload.where(sha1: sha1, original_sha1: nil))
    end

    def execute
      uploads = search_images
      posts = Post.joins(:uploads).merge(uploads)
      posts = filter_post(posts)
      post.select("posts.*,uploads.id as upload_id").includes(topic: [:category,:tags])
    end

    def filter_post(posts)
      posts = posts.joins(topic: :category)\
        .where('categories.read_restricted' => false)\
        .where("topics.archetype" => "regular")\
        .where("topics.visible" => true)
      if SiteSetting.tagging_enabled && SiteSetting.image_enhancement_ignored_tags.present?
        posts = posts.where("NOT EXISTS (
          SELECT 1
          FROM topic_tags
          INNER JOIN tags ON topic_tags.tag_id = tags.id
          WHERE topic_tags.topic_id = topics.id
          AND tags.name IN (?)
        )", SiteSetting.image_enhancement_ignored_tags.split('|'))
      end
      posts
    end
  end
end