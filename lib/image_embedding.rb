# frozen_string_literal: true

module ::DiscourseImageEnhancement
  class ImageEmbedding
    # Embeds a single image using the analysis service, with caching.
    #
    # @param uploaded_file [ActionDispatch::Http::UploadedFile] The uploaded image file.
    # @return [Array<Float>, nil] The embedding vector if successful, otherwise nil.
    def self.embed_image(uploaded_file)
      unless uploaded_file && uploaded_file.respond_to?(:tempfile) &&
               File.exist?(uploaded_file.tempfile.path)
        return nil
      end

      file_hash = Digest::MD5.file(uploaded_file.tempfile.path).hexdigest

      cache_key = "image_embedding_#{file_hash}"

      Discourse
        .cache
        .fetch(cache_key, expires_in: 5.minutes) { perform_embedding_request(uploaded_file) }
    end

    private

    def self.perform_embedding_request(uploaded_file)
      base_uri = URI.parse(SiteSetting.image_enhancement_analyze_service_endpoint)
      uri = URI.join(base_uri, "/image_embedding/")
      image_data = File.binread(uploaded_file.tempfile.path)
      base64_image = Base64.strict_encode64(image_data)
      data_uri = "data:#{uploaded_file.content_type};base64,#{base64_image}"
      body = JSON.dump({ image: data_uri })
      headers = build_request_headers(uri)

      connection =
        Faraday.new do |f|
          f.adapter FinalDestination::FaradayAdapter
          f.options.timeout = 30
          f.options.open_timeout = 30
        end
      response = connection.post(uri, body, headers)

      if response.status != 200
        Rails.logger.warn("Failed to embed image #{response.status}: #{response.body}")
        raise "Failed to embed image #{response.status}: #{response.body}"
      end

      result = JSON.parse(response.body, symbolize_names: true)
      raise "Failed to embed image #{response.status}: #{response.body}" unless result[:success]
      result[:embedding]
    end

    def self.build_request_headers(uri)
      {
        "Host" => uri.host,
        "User-Agent" => "Discourse/#{Discourse::VERSION::STRING}",
        "X-Discourse-Instance" => Discourse.base_url,
        "api-key" => SiteSetting.image_enhancement_analyze_service_key,
      }
    end
  end
end
