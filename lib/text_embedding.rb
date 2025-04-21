# frozen_string_literal: true
module ::DiscourseImageEnhancement
  class TextEmbedding
    def self.embed_text(text)
      Array.new(512) { rand }
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
