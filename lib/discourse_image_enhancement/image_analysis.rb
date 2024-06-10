module ::DiscourseImageEnhancement
  class ImageAnalysis
    def self.process_post(post)
      return nil unless should_analyze_post(post)
      image_info = extract_images(post)
      return nil unless image_info.present?
      return nil if image_info.length > SiteSetting.image_enhancement_max_images_per_post
      body = build_query_body(image_info)
      uri = URI.parse(SiteSetting.image_enhancement_analyze_service_endpoint)
      headers = build_query_headers(uri, body)

      connection = Faraday.new do |f|
        f.adapter FinalDestination::FaradayAdapter
      end

      begin
        response = connection.post(uri, body, headers)
      rescue => e
        Rails.logger.warn("Failed to analyze images for post #{post.id}: #{e.message}")
        return nil
      end

      if response.status != 200
        Rails.logger.warn("Failed to analyze images for post #{post.id}")
        return nil
      end

      begin
        result = MultiJson.load(response.body)
        result["images"].each do |image|
          next unless image["success"]
          save_analyzed_image_data(image)
        end
      end
    end

    def self.save_analyzed_image_data(image)
      params = {
        sha1: image["sha1"],
        ocr_text: image["ocr_text"],
        description: image["description"],
        ocr_text_search_data: Search.prepare_data(image["ocr_text"]),
        description_search_data: Search.prepare_data(image["description"]),
        ts_config: Search.ts_config
      }
      DB.exec(<<~SQL, params)
        INSERT INTO image_search_data (sha1, ocr_text, description, ocr_text_search_data, description_search_data)
        VALUES (:sha1, :ocr_text, :description, to_tsvector(:ts_config, :ocr_text_search_data), to_tsvector(:ts_config, :description_search_data))
        ON CONFLICT (sha1) DO NOTHING
      SQL
    end

    def self.should_analyze_image(upload)
      return false unless upload.present?
      return false unless FileHelper.is_supported_image?(upload.original_filename)
      return false if upload.filesize > SiteSetting.image_enhancement_max_image_size_kb.kilobytes
      return false if upload.width < SiteSetting.image_enhancement_min_image_width
      return false if upload.height < SiteSetting.image_enhancement_min_image_height
      sha1 = upload.original_sha1 || upload.sha1
      return false if ImageSearchData.find_by(sha1: sha1).present?
      true
    end

    def self.should_analyze_post(post)
      return false if post.blank?
      return true if SiteSetting.image_enhancement_ignored_tags.blank?
      return false unless post.topic.tags.present?
      ignored_tags = SiteSetting.image_enhancement_ignored_tags.split("|")
      return false if post.topic.tags.any? { |t| ignored_tags.include?(t) }
      true
    end

    def self.extract_images(post)
      post.uploads.filter { |u| should_analyze_image(u) }.map do |u|
        url = UrlHelper.cook_url(u.url, secure: u.secure)
        url = Upload.signed_url_from_secure_uploads_url(url) if Upload.secure_uploads_url?(url)
        {
          id: u.id,
          sha1: u.original_sha1 || u.sha1,
          url: url
        }
      end
    end

    def self.build_query_body(images)
      body = {}
      body[:images] = images
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
      }
    end

    def self.should_analyze_image?(upload)
      return false unless upload.present?
      return false unless FileHelper.is_supported_image?(upload.original_filename)
      return false if upload.filesize > SiteSetting.image_enhancement_max_image_size_kb.kilobytes
      return false if upload.width < SiteSetting.image_enhancement_min_image_width
      return false if upload.height < SiteSetting.image_enhancement_min_image_height
      sha1 = upload.original_sha1 || upload.sha1
      return false if ImageSearchData.find_by(sha1: sha1).present?
      true
    end

    def self.extract_images(post)
      post.uploads.filter { |u| should_analyze_image(u) }.map do |u|
        url = UrlHelper.cook_url(u.url, secure: u.secure)
        url = Upload.signed_url_from_secure_uploads_url(url) if Upload.secure_uploads_url?(url)
        {
          id: u.id,
          sha1: u.original_sha1 || u.sha1,
          url: url
        }
      end
    end
  end
end