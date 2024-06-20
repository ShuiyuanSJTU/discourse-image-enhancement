module ::DiscourseImageEnhancement
  class ImageAnalysis
    def self.process_post(post, record_failed: true)
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
        Rails.logger.warn("Failed to analyze images for post #{post.id}, #{response.status}: #{response.body}")
        return nil
      end

      valid_sha1s = image_info.map { |i| i[:sha1] }
      result = MultiJson.load(response.body)
      result["images"].each do |image|
        next unless image["success"]
        next unless valid_sha1s.include?(image["sha1"])
        save_analyzed_image_data(image)
      end

      if record_failed
        success_sha1s = result["images"].select { |i| i["success"] }.map { |i| i["sha1"] }
        failed_sha1s = image_info.map { |i| i[:sha1] } - success_sha1s
        if failed_sha1s.present?
          failed_count = PluginStore.get(PLUGIN_NAME, "failed_count") || {}
          failed_sha1s.each do |sha1|
            failed_count[sha1] = (failed_count[sha1] || 0) + 1
          end
          PluginStore.set(PLUGIN_NAME, "failed_count", failed_count)
        end
      end

      result
    end

    def self.save_analyzed_image_data(image)
      params = {
        sha1: image["sha1"],
        ocr_text: image["ocr_result"].join("\n"),
        description: image["description"],
        ocr_text_search_data: Search.prepare_data(image["ocr_result"].join("\n"), :index),
        description_search_data: Search.prepare_data(image["description"], :index),
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
      return true if Filter.filter_upload(
        Upload.where(id: upload), max_retry_times: -1).count > 0
      true
    end

    def self.should_analyze_post(post)
      return false if post.blank? || post.id.blank?
      return true if Filter.filter_post(Post.where(id: post)).count > 0
      false
    end

    def self.extract_images(post)
      Filter.filter_upload(post.uploads).map do |u|
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
        "api-key" => SiteSetting.image_enhancement_analyze_service_key
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

    def self.check_for_flag(post)
      return unless SiteSetting.image_enhancement_auto_flag_ocr
      ocr_text = ImageSearchData.find_by_post(post).pluck(:ocr_text).join("\n")
      if WordWatcher.new(ocr_text).should_flag?
        PostActionCreator.create(
          Discourse.system_user,
          post,
          :inappropriate,
          reason: :watched_word,
        )
      end
    end
  end
end