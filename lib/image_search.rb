# frozen_string_literal: true

module ::DiscourseImageEnhancement
  class ImageSearch
    def initialize(
      term,
      image = nil,
      limit: 20,
      page: 0,
      ocr: true,
      embeddings: true,
      by_image: false,
      guardian: nil
    )
      @term = term.to_s
      @image = image
      @limit = limit
      @page = page
      @search_ocr = ocr
      @search_embeddings = embeddings
      @search_by_image = by_image
      @guardian = guardian || Guardian.new
      @advanced_filter = AdvancedFilter.new

      # call process_advanced_search! to register the advanced filters
      # and remove the advanced filters from the term
      @processed_term = @term.present? ? @advanced_filter.process_advanced_search!(@term) : ""
      @target_embed = nil

      if @search_by_image
        if @search_ocr || @search_embeddings
          Rails.logger.warn(
            "search_by_image is not compatible with search_ocr or search_embeddings",
          )
          @search_ocr = false
          @search_embeddings = false
        end
      end
    end

    def embed_search_target
      return @target_embed if @target_embed
      if @search_by_image
        @target_embed = Embedding.embed(@image, type: :image)
      elsif @search_embeddings
        @target_embed = Embedding.embed(@processed_term, type: :text)
      end
    end

    def apply_advanced_filters(posts)
      @advanced_filter.apply_advanced_filters(posts)
    end

    def search_posts_ocr(term = nil, limit:, offset:)
      posts = apply_advanced_filters(Post.visible.public_posts)
      search_result_images = search_images_ocr(term)
      posts = posts.joins(:uploads).where(uploads: { id: search_result_images })
      posts = posts.order("posts.id": :desc)
      posts = posts.offset(@page * offset).limit(limit)
    end

    def search_images_ocr(term = nil)
      # OCR search result is chainable, so we do not need to
      # set limit and offset here
      # OCR search is only true or false, do not calculate similarity
      term = @processed_term if term.nil?
      return nil if term.blank? || !@search_ocr
      # user input will be quoted after to_tsquery, we can safely interpolate it
      @safe_term_tsquery =
        Search.ts_query(term: Search.prepare_data(term, :query), ts_config: Search.ts_config)

      images = Upload.joins(:image_search_data)

      images.where("ocr_text_search_data @@ #{@safe_term_tsquery}")
    end

    def search_posts_embedding(target_embed = nil, limit:, offset:, threshold: 0)
      # For search-by-image or search-by-content, if no target_embed is provided,
      # we will use the embed_search_target method to get the target_embed
      # This function first filter out candidate images, and then search for posts
      # that contain those images
      # The `limit` and `offset` are applied to the images result, not the posts result
      # So there may be more posts in the result than the `limit`

      posts = apply_advanced_filters(Post.visible.public_posts)
      search_result_images =
        search_images_embedding(target_embed, limit: limit, offset: offset, threshold: threshold)
      image_ids = search_result_images.map(&:upload_id)
      return Post.joins(:uploads).none if image_ids.blank?
      posts
        .joins(:uploads)
        .where(uploads: { id: image_ids })
        .order(["array_position(ARRAY[?], uploads.id)", image_ids])
    end

    def search_images_embedding(target_embed = nil, limit:, offset:, threshold: 0)
      target_embed = embed_search_target if target_embed.nil?
      before_query = self.class.hnsw_search_workaround(limit)

      builder = DB.build(<<~SQL)
        WITH candidates AS (
          SELECT
            upload_id,
            embeddings::halfvec(512) AS embeddings
          FROM
            image_search_data
          ORDER BY
            binary_quantize(embeddings)::bit(512) <~> binary_quantize('[:query_embedding]'::halfvec(512))
          LIMIT :candidates_limit
        )
        SELECT
          upload_id
        FROM
          candidates
        WHERE
          (1 - (embeddings::halfvec(512) <=> '[:query_embedding]'::halfvec(512))) >= :threshold
        ORDER BY
          embeddings::halfvec(512) <=> '[:query_embedding]'::halfvec(512)
        LIMIT :limit
        OFFSET :offset;
      SQL

      ActiveRecord::Base.transaction do
        DB.exec(before_query) if before_query.present?
        builder.query(
          query_embedding: target_embed,
          candidates_limit: limit * 2 + offset,
          limit: limit,
          offset: offset,
          threshold: threshold,
        )
      end
    rescue PG::Error => e
      Rails.logger.error("Error #{e} querying embeddings")
      raise e
    end

    def execute
      # results is an array of [post_id, upload_id]

      if @search_embeddings && @search_ocr
        limit = (@limit / 2).to_i
        res_embedding =
          search_posts_embedding(
            limit: limit,
            offset: @page * limit,
            threshold: SiteSetting.image_enhancement_text_embedding_similarity_threshold,
          ).pluck("posts.id", "uploads.id")
        res_ocr =
          search_posts_ocr(limit: limit, offset: @page * limit).pluck("posts.id", "uploads.id")
        has_more = res_embedding.length >= limit || res_ocr.length >= limit
        # sort by post id descending
        results = (res_embedding + res_ocr).sort_by(&:first).reverse
      elsif @search_ocr
        results =
          search_posts_ocr(limit: @limit, offset: @page * @limit).pluck("posts.id", "uploads.id")
        has_more = results.length >= @limit
      elsif @search_embeddings || @search_by_image
        threshold =
          (
            if @search_by_image
              SiteSetting.image_enhancement_image_embedding_similarity_threshold
            elsif @search_embeddings
              SiteSetting.image_enhancement_text_embedding_similarity_threshold
            else
              nil
            end
          )
        results =
          search_posts_embedding(limit: @limit, offset: @page * @limit, threshold: threshold).pluck(
            "posts.id",
            "uploads.id",
          )
        has_more = results.length >= @limit
      else
        results = []
        has_more = false
      end

      posts_id, uploads_id = results.uniq.transpose
      ImageSearchResult.new(
        posts_id,
        uploads_id,
        term: @term,
        processed_term: @processed_term,
        search_ocr: @search_ocr,
        search_embeddings: @search_embeddings,
        search_by_image: @search_by_image,
        page: @page,
        limit: @limit,
        has_more: has_more,
      )
    end

    DEFAULT_HNSW_EF_SEARCH = 40
    def self.hnsw_search_workaround(limit)
      threshold = (limit * 2).to_i

      return "" if threshold < DEFAULT_HNSW_EF_SEARCH
      "SET LOCAL hnsw.ef_search = #{threshold};"
    end
  end
end
