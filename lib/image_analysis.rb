# frozen_string_literal: true
module ::DiscourseImageEnhancement
  class ImageAnalysis
    def self.process_post(post, record_failed: true)
      return nil unless should_analyze_post(post)
      image_info = extract_images(post)
      return nil if image_info.blank?
      return nil if image_info.length > SiteSetting.image_enhancement_max_images_per_post
      body = build_query_body(image_info)
      uri = URI.parse(SiteSetting.image_enhancement_analyze_service_endpoint)
      headers = build_query_headers(uri, body)

      connection = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }

      begin
        response = connection.post(uri, body, headers)
      rescue => e
        Rails.logger.warn("Failed to analyze images for post #{post.id}: #{e.message}")
        return nil
      end

      if response.status != 200
        Rails.logger.warn(
          "Failed to analyze images for post #{post.id}, #{response.status}: #{response.body}",
        )
        return nil
      end

      sha1_to_upload_id = image_info.map { |i| [i[:sha1], i[:id]] }.to_h
      result = MultiJson.load(response.body)
      result["images"].each do |image|
        next unless image["success"]
        upload_id = sha1_to_upload_id[image["sha1"]]
        next if upload_id.blank?
        save_analyzed_image_data(image, Upload.find_by(id: upload_id))
      end

      if record_failed
        success_sha1s = result["images"].select { |i| i["success"] }.map { |i| i["sha1"] }
        failed_sha1s = image_info.map { |i| i[:sha1] } - success_sha1s
        if failed_sha1s.present?
          failed_count = PluginStore.get(PLUGIN_NAME, "failed_count") || {}
          failed_sha1s.each { |sha1| failed_count[sha1] = (failed_count[sha1] || 0) + 1 }
          PluginStore.set(PLUGIN_NAME, "failed_count", failed_count)
        end
      end

      result
    end

    def self.save_analyzed_image_data(image, upload)
      return if ImageSearchData.find_by(upload_id: upload.id).present?
      if SiteSetting.image_enhancement_analyze_ocr_enabled
        ocr_text = image["ocr_result"].join("\n")
        ocr_text_search_data = Search.prepare_data(ocr_text, :index)
      else
        ocr_text = nil
        ocr_text_search_data = nil
      end
      if SiteSetting.image_enhancement_analyze_description_enabled
        description = image["description"]
        description_search_data = Search.prepare_data(description, :index)
      else
        description = nil
        description_search_data = nil
      end
      params = {
        upload_id: upload.id,
        sha1: image["sha1"],
        ocr_text: ocr_text,
        description: description,
        ocr_text_search_data: ocr_text_search_data,
        description_search_data: description_search_data,
        ts_config: Search.ts_config,
      }
      DB.exec(<<~SQL, params)
        INSERT INTO image_search_data (upload_id, sha1, ocr_text, description, ocr_text_search_data, description_search_data)
        VALUES (:upload_id, :sha1, :ocr_text, :description, to_tsvector(:ts_config, :ocr_text_search_data), to_tsvector(:ts_config, :description_search_data))
        ON CONFLICT (upload_id) DO NOTHING
      SQL
    end

    def self.should_analyze_image(upload)
      return false if upload.blank?
      return true if Filter.filter_upload(Upload.where(id: upload), max_retry_times: -1).count > 0
      true
    end

    def self.should_analyze_post(post)
      return false if post.blank? || post.id.blank?
      return true if Filter.filter_post(Post.where(id: post)).count > 0
      false
    end

    def self.extract_images(post)
      Filter
        .filter_upload(post.uploads)
        .map do |u|
          url = UrlHelper.cook_url(u.url, secure: u.secure)
          url = Upload.signed_url_from_secure_uploads_url(url) if Upload.secure_uploads_url?(url)
          { id: u.id, sha1: u.original_sha1 || u.sha1, url: url }
        end
    end

    def self.build_query_body(images)
      body = {}
      body[:images] = images
      body[:ocr] = SiteSetting.image_enhancement_analyze_ocr_enabled
      body[:description] = SiteSetting.image_enhancement_analyze_description_enabled
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

    def self.check_for_flag(post)
      return unless SiteSetting.image_enhancement_auto_flag_ocr
      ocr_text = ImageSearchData.find_by_post(post).pluck(:ocr_text).join("\n")
      if ocr_text.present? && WordWatcher.new(ocr_text).should_flag?
        PostActionCreator.create(Discourse.system_user, post, :inappropriate, reason: :watched_word)
      end
    end
  end
end
