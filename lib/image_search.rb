# frozen_string_literal: true

module ::DiscourseImageEnhancement
  class ImageSearch
    def initialize(
      term,
      limit: 20,
      page: 0,
      ocr: true,
      description: true,
      embeddings: true,
      guardian: nil
    )
      @term = term
      @limit = limit
      @page = page
      @ocr = ocr
      @description = description
      @embeddings = embeddings
      @has_more = true
      @guardian = guardian || Guardian.new
      @advanced_filter = AdvancedFilter.new
      @processed_term = @advanced_filter.process_advanced_search!(@term)
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
      return nil if term.blank? || !@ocr
      # user input will be quoted after to_tsquery, we can safely interpolate it
      @safe_term_tsquery =
        Search.ts_query(term: Search.prepare_data(term, :query), ts_config: Search.ts_config)

      images = Upload.joins(:image_search_data)

      images.where("ocr_text_search_data @@ #{@safe_term_tsquery}")
    end

    def search_posts_embedding(term = nil, limit:, offset:)
      posts = apply_advanced_filters(Post.visible.public_posts)
      search_result_images = search_images_embedding(term, limit: limit, offset: offset)
      image_ids = search_result_images.map(&:upload_id)
      return Post.joins(:uploads).none if image_ids.blank?
      posts
        .joins(:uploads)
        .where(uploads: { id: image_ids })
        .order(["array_position(ARRAY[?], uploads.id)", image_ids])
    end

    def search_images_embedding(term = nil, limit:, offset:)
      term = @processed_term if term.nil?

      embedding = TextEmbedding.embed_text(term)

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
          (embeddings::halfvec(512) <=> '[:query_embedding]'::halfvec(512)) >= :threshold
        ORDER BY
          (embeddings::halfvec(512) <=> '[:query_embedding]'::halfvec(512)) DESC
        LIMIT :limit
        OFFSET :offset;
      SQL

      ActiveRecord::Base.transaction do
        DB.exec(before_query) if before_query.present?
        builder.query(
          query_embedding: embedding,
          candidates_limit: limit * 2 + offset,
          limit: limit,
          offset: offset,
          threshold: SiteSetting.image_enhancement_embedding_similarity_threshold,
        )
      end
    rescue PG::Error => e
      Rails.logger.error("Error #{e} querying embeddings")
      raise e
    end

    def execute
      # results is an array of [post_id, upload_id]
      results =
        begin
          if @embeddings && @ocr
            limit = (@limit / 2).to_i
            res_embedding =
              search_posts_embedding(limit: limit, offset: @page * limit).pluck(
                "posts.id",
                "uploads.id",
              )
            res_ocr =
              search_posts_ocr(limit: limit, offset: @page * limit).pluck("posts.id", "uploads.id")
            @has_more = res_embedding.length >= limit || res_ocr.length >= limit
            res_embedding + res_ocr
          elsif @ocr
            res =
              search_posts_ocr(limit: @limit, offset: @page * @limit).pluck(
                "posts.id",
                "uploads.id",
              )
            @has_more = res.length >= @limit
            res
          elsif @embeddings
            res =
              search_posts_embedding(limit: @limit, offset: @page * @limit).pluck(
                "posts.id",
                "uploads.id",
              )
            @has_more = res.length >= @limit
            res
          else
            nil
          end
        end

      posts_id, uploads_id = results.uniq.transpose
      ImageSearchResult.new(
        posts_id,
        uploads_id,
        term: @term,
        search_ocr: @ocr,
        search_description: @description,
        search_embeddings: @embeddings,
        page: @page,
        limit: @limit,
        has_more: @has_more,
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
