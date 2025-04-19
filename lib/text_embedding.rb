# frozen_string_literal: true
module ::DiscourseImageEnhancement
  class TextEmbedding
    def self.embed_text(text)
      
    end

    def self.asymmetric_similarity_search(embedding, limit:, offset:)
      before_query = hnsw_search_workaround(limit)
      
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
          embeddings::halfvec(512) #>> '[:query_embedding]'::halfvec(512)
        LIMIT :limit
        OFFSET :offset;
      SQL

      candidates_limit = limit * 2
    
      ActiveRecord::Base.transaction do
        DB.exec(before_query) if before_query.present?
        builder.query(
          query_embedding: embedding,
          candidates_limit: candidates_limit,
          limit: limit,
          offset: offset,
        )
      end
    rescue PG::Error => e
      Rails.logger.error("Error #{e} querying embeddings")
      raise MissingEmbeddingError
    end

    def self.build_query_body(text)
      body = {}
      body[:text] = text
      MultiJson.dump(body)
    end

    def self.build_query_headers(uri, query_body)
      {
        "Accept" => "*/*",
        "Connection" => "close",
        "Content-Type" => "application/json",
        "Content-Length" => query_body.bytesize.to_s,
        "Host" => uri.host,
        "User-Agent" => "Discourse/#{Discourse::VERSION::STRING}",
        "X-Discourse-Instance" => Discourse.base_url,
        "api-key" => SiteSetting.image_enhancement_analyze_service_key,
      }
    end

    DEFAULT_HNSW_EF_SEARCH = 40
    def self.hnsw_search_workaround(limit)
      threshold = (limit * 2).to_i

      return "" if threshold < DEFAULT_HNSW_EF_SEARCH
      "SET LOCAL hnsw.ef_search = #{threshold};"
    end
  end
end
