# frozen_string_literal: true
module ::DiscourseImageEnhancement
  class TextEmbedding
    def self.embed_text(text)
      cache_key = "text_embedding_#{Digest::MD5.hexdigest(text)}"
      Discourse.cache.fetch(cache_key, expires_in: 5.minutes) { perform_embedding_request(text) }
    end

    private

    def self.perform_embedding_request(text)
      base_uri = URI.parse(SiteSetting.image_enhancement_analyze_service_endpoint)
      uri = URI.join(base_uri, "/text_embedding/")
      body = { text: text }
      headers = build_query_headers(uri)

      connection =
        Faraday.new do |f|
          f.request :json
          f.adapter FinalDestination::FaradayAdapter
          f.options.timeout = 30
          f.options.open_timeout = 30
        end

      response = connection.post(uri, body, headers)

      if response.status != 200
        Rails.logger.warn("Failed to embed text #{response.status}: #{response.body}")
        raise "Failed to embed text #{response.status}: #{response.body}"
      end

      result = JSON.parse(response.body, symbolize_names: true)
      raise "Failed to embed text #{response.status}: #{response.body}" unless result[:success]
      result[:embedding]
    end

    def self.build_query_headers(uri)
      {
        "Host" => uri.host,
        "User-Agent" => "Discourse/#{Discourse::VERSION::STRING}",
        "X-Discourse-Instance" => Discourse.base_url,
        "api-key" => SiteSetting.image_enhancement_analyze_service_key,
      }
    end
  end
end
