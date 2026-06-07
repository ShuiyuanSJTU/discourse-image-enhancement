# frozen_string_literal: true

module ::DiscourseImageEnhancement
  class Embedding
    # Embeds content (image or text) using the analysis service, with caching.
    #
    # @param content [ActionDispatch::Http::UploadedFile, String] The uploaded image file or text.
    # @param type [Symbol] The type of content (:image or :text).
    # @return [Array<Float>, nil] The embedding vector if successful, otherwise nil.
    def self.embed(content, type: :text)
      cache_key =
        if type == :image
          return nil unless content.respond_to?(:tempfile) && File.exist?(content.tempfile.path)
          file_hash = Digest::MD5.file(content.tempfile.path).hexdigest
          "image_embedding_#{file_hash}"
        else
          "text_embedding_#{Digest::MD5.hexdigest(content)}"
        end

      Discourse
        .cache
        .fetch(cache_key, expires_in: 5.minutes) { perform_embedding_request(content, type) }
    end

    private

    def self.perform_embedding_request(content, type)
      uri = embedding_uri(type)
      headers = build_request_headers

      body =
        if type == :image
          image_data = File.binread(content.tempfile.path)
          base64_image = Base64.strict_encode64(image_data)
          data_uri = "data:#{content.content_type};base64,#{base64_image}"
          { image: data_uri }
        else
          { text: content }
        end

      response = embedding_connection.post(uri, body, headers)
      if response.status != 200
        raise_embedding_error(type, "status=#{response.status} body=#{response.body}")
      end

      result = JSON.parse(response.body, symbolize_names: true)
      embedding = result[:embedding] if result.is_a?(Hash)

      if !result.is_a?(Hash) || !result[:success] || !embedding.is_a?(Array)
        raise_embedding_error(type, "invalid response body=#{response.body}")
      end

      embedding
    rescue Faraday::Error, JSON::ParserError, URI::Error => e
      raise_embedding_error(type, e.message)
    end

    def self.embedding_uri(type)
      base_uri = URI.parse(SiteSetting.image_enhancement_analyze_service_endpoint)
      URI.join(base_uri, "./#{type}_embedding/")
    end

    def self.embedding_connection
      Faraday.new do |f|
        f.request :json
        f.adapter FinalDestination::FaradayAdapter
        f.options.timeout = 30
        f.options.open_timeout = 30
      end
    end

    def self.build_request_headers
      {
        "User-Agent" => "Discourse/#{Discourse::VERSION::STRING}",
        "X-Discourse-Instance" => Discourse.base_url,
        "api-key" => SiteSetting.image_enhancement_analyze_service_key,
      }
    end

    def self.raise_embedding_error(type, details)
      Rails.logger.warn("Failed to embed #{type}: #{details}")
      raise ExternalServiceError, "Failed to generate embedding"
    end
  end
end
