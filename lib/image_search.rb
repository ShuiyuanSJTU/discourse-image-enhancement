# frozen_string_literal: true
require_relative "image_search/image_search_result"

module ::DiscourseImageEnhancement
  class ImageSearch
    def initialize(term, limit: 20, page: 0, ocr: true, description: true, embeddings: true, guardian: nil)
      @term = term
      @limit = limit
      @page = page
      @ocr = ocr
      @description = description
      @embeddings = embeddings
      @has_more = true
      @guardian = guardian || Guardian.new
    end

    def search_images(term = nil)
      search_images_ocr(term)
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
      term ||= @term
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
      posts = posts.joins(:uploads).where(uploads: { id: image_ids })
      posts
    end

    def search_images_embedding(term=nil, limit:, offset:)
      term = @term if term.nil?

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
        ORDER BY
          embeddings::halfvec(512) <#> '[:query_embedding]'::halfvec(512)
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
        )
      end
    rescue PG::Error => e
      Rails.logger.error("Error #{e} querying embeddings")
      raise e
    end

    def execute
      term = process_advanced_search!(@term)

      # results is ActiveRecord_Relation: Post.joins(:uploads)
      results = begin
        if @embeddings && @ocr
          limit = (@limit / 2).to_i
          res_embedding = search_posts_embedding(term, limit: limit, offset: @page * limit).pluck("posts.id","uploads.id")
          res_ocr = search_posts_ocr(term, limit: limit, offset: @page * limit).pluck("posts.id","uploads.id")
          @has_more = res_embedding.length >= limit || res_ocr.length >= limit
          res_embedding + res_ocr
        elsif @ocr
          res = search_posts_ocr(term, limit: @limit, offset: @page * @limit).pluck("posts.id","uploads.id")
          @has_more = res.length >= @limit
          res
        elsif @embeddings
          res = search_posts_embedding(term, limit: @limit, offset: @page * @limit).pluck("posts.id","uploads.id")
          @has_more = res.length >= @limit
          res
        else
          nil
        end
      end
      
      posts_id, uploads_id = results.uniq.transpose
      ImageSearchResult.new(
        posts_id, uploads_id,
        term: @term,
        search_ocr: @ocr,
        search_description: @description,
        search_embeddings: @embeddings,
        page: @page,
        limit: @limit,
        has_more: @has_more,
      )
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

    advanced_filter(/\Atopic:(\d+)\z/i) { |posts, match| posts.where(topic_id: match.to_i) }

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
      posts.where(id: Post.joins({ topic: :tags }).where(tags: { id: tags }))
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

        posts.joins(:topic).where({ topics: { category_id: category_ids } })
      else
        posts.none
      end
    end

    DEFAULT_HNSW_EF_SEARCH = 40
    def self.hnsw_search_workaround(limit)
      threshold = (limit * 2).to_i

      return "" if threshold < DEFAULT_HNSW_EF_SEARCH
      "SET LOCAL hnsw.ef_search = #{threshold};"
    end
  end
end
