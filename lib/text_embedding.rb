# frozen_string_literal: true
module ::DiscourseImageEnhancement
  class TextEmbedding
    def self.embed_text(text)
      body = build_query_body(text)
      base_uri = URI.parse(SiteSetting.image_enhancement_analyze_service_endpoint)
      uri = URI.join(base_uri, "/text_embedding/")
      headers = build_query_headers(uri, body)

      connection = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }

      begin
        response = connection.post(uri, body, headers)
      rescue => e
        Rails.logger.warn("Failed to embed text: #{e.message}")
        return nil
      end

      if response.status != 200
        Rails.logger.warn(
          "Failed to embed text #{response.status}: #{response.body}",
        )
        return nil
      end

      result = JSON.parse(response.body, symbolize_names: true)
      return nil unless result[:success]
      result[:embedding]
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
  end
end
