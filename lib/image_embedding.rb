# frozen_string_literal: true

module ::DiscourseImageEnhancement
  class ImageEmbedding
    # Embeds a single image using the analysis service, with caching.
    #
    # @param uploaded_file [ActionDispatch::Http::UploadedFile] The uploaded image file.
    # @return [Array<Float>, nil] The embedding vector if successful, otherwise nil.
    def self.embed_image(uploaded_file)
      return nil unless uploaded_file && uploaded_file.respond_to?(:tempfile) && File.exist?(uploaded_file.tempfile.path)

      file_hash = Digest::MD5.file(uploaded_file.tempfile.path).hexdigest

      cache_key = "image_embedding_#{file_hash}"

      Discourse.cache.fetch(cache_key, expires_in: 5.minutes) do
        perform_embedding_request(uploaded_file)
      end
    end

    private

    def self.perform_embedding_request(uploaded_file)
      base_uri = URI.parse(SiteSetting.image_enhancement_analyze_service_endpoint)
      uri = URI.join(base_uri, "/image_embedding/")

      payload = { image: Faraday::Multipart::FilePart.new(uploaded_file.tempfile.path, uploaded_file.content_type, uploaded_file.original_filename) }

      headers = build_request_headers(uri)

      connection = Faraday.new do |f|
        f.request :multipart
        f.request :url_encoded
        f.adapter FinalDestination::FaradayAdapter
        f.options.timeout = 10
        f.options.open_timeout = 10
      end

      begin
        response = connection.post(uri, payload, headers)
      rescue Faraday::TimeoutError => e
        Rails.logger.warn("Image embedding request timed out: #{e.message}")
        return nil
      rescue => e
        Rails.logger.warn("Failed to embed image: #{e.message}")
        return nil
      end

      if response.status != 200
        Rails.logger.warn("Failed to embed image #{response.status}: #{response.body}")
        return nil
      end

      result = JSON.parse(response.body, symbolize_names: true)
      return nil unless result[:success]
      result[:embedding]
    end


    def self.build_request_headers(uri)
      {
        "Accept" => "application/json",
        "Connection" => "close",
        "Host" => uri.host,
        "User-Agent" => "Discourse/#{Discourse::VERSION::STRING}",
        "X-Discourse-Instance" => Discourse.base_url,
        "api-key" => SiteSetting.image_enhancement_analyze_service_key,
        # Content-Type and Content-Length are handled by Faraday for multipart
      }
    end
  end
end