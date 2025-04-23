# frozen_string_literal: true
module ::DiscourseImageEnhancement
  class ImageAnalysis
    def initialize(
      record_failed: true,
      analyze_ocr: nil,
      analyze_embedding: nil,
      auto_flag_ocr: nil
    )
      @record_failed = record_failed
      @analyze_ocr =
        analyze_ocr.nil? ? SiteSetting.image_enhancement_analyze_ocr_enabled : analyze_ocr
      @analyze_embedding =
        (
          if analyze_embedding.nil?
            SiteSetting.image_enhancement_analyze_embedding_enabled
          else
            analyze_embedding
          end
        )
      @auto_flag_ocr =
        auto_flag_ocr.nil? ? SiteSetting.image_enhancement_auto_flag_ocr : auto_flag_ocr
    end

    def analyze_images(image_info)
      body = build_query_body(image_info)
      base_uri = URI.parse(SiteSetting.image_enhancement_analyze_service_endpoint)
      uri = URI.join(base_uri, "/analyze/")
      headers = build_query_headers(uri, body)

      connection = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }

      begin
        response = connection.post(uri, body, headers)
      rescue => e
        Rails.logger.warn("Failed to analyze images: #{e.message}")
        return nil
      end

      if response.status != 200
        Rails.logger.warn("Failed to analyze images #{response.status}: #{response.body}")
        return nil
      end

      sha1_to_upload_id = image_info.map { |i| [i[:sha1], i[:id]] }.to_h
      result = JSON.parse(response.body, symbolize_names: true)
      result[:images].each do |image_result|
        next unless image_result[:success]
        upload_id = sha1_to_upload_id[image_result[:sha1]]
        next if upload_id.blank?
        save_analyzed_image_data(image_result, Upload.find_by(id: upload_id))
      end

      if @record_failed
        success_sha1s = result[:images].select { |i| i[:success] }.map { |i| i[:sha1] }
        failed_sha1s = image_info.map { |i| i[:sha1] } - success_sha1s
        if failed_sha1s.present?
          failed_count = PluginStore.get(PLUGIN_NAME, "failed_count") || {}
          failed_sha1s.each { |sha1| failed_count[sha1] = (failed_count[sha1] || 0) + 1 }
          PluginStore.set(PLUGIN_NAME, "failed_count", failed_count)
        end
      end

      result
    end

    def process_post(post)
      return nil unless should_analyze_post(post)
      image_info = extract_images(post.uploads)
      return nil if image_info.blank?
      return nil if image_info.length > SiteSetting.image_enhancement_max_images_per_post
      analyze_images(image_info)
      check_for_flag(post)
    end

    def process_image(upload)
      return nil if upload.blank?
      image_info = extract_images(Upload.where(id: upload.id))
      return nil if image_info.blank?
      existing_search_data = ImageSearchData.find_by(upload_id: upload.id)
      if existing_search_data.present?
        @analyze_ocr = false if existing_search_data.ocr_text.present?
        @analyze_embedding = false if existing_search_data.embedding.present?
      end
      analyze_images(image_info)
    end

    def save_analyzed_image_data(image_result, upload)
      if @analyze_ocr && !image_result[:ocr_result].nil?
        ocr_text = image_result[:ocr_result].join("\n")
        ocr_text_search_data = Search.prepare_data(ocr_text, :index)
      else
        ocr_text = nil
        ocr_text_search_data = nil
      end
      if @analyze_embedding && !image_result[:embedding].nil?
        embedding = image_result[:embedding].to_s
      else
        embedding = nil
      end
      return if ocr_text.nil? && embedding.nil?
      params = {
        upload_id: upload.id,
        sha1: image_result[:sha1],
        ocr_text: ocr_text,
        ocr_text_search_data: ocr_text_search_data,
        ts_config: Search.ts_config,
        embedding: embedding,
      }
      DB.exec(<<~SQL, params)
        INSERT INTO image_search_data (upload_id, sha1, ocr_text, ocr_text_search_data, embeddings)
        VALUES (:upload_id, :sha1, :ocr_text, to_tsvector(:ts_config, :ocr_text_search_data), :embedding)
        ON CONFLICT (upload_id) DO UPDATE SET
          ocr_text = COALESCE(EXCLUDED.ocr_text, image_search_data.ocr_text),
          ocr_text_search_data = COALESCE(EXCLUDED.ocr_text_search_data, image_search_data.ocr_text_search_data),
          embeddings = COALESCE(EXCLUDED.embeddings, image_search_data.embeddings)
      SQL
    end

    def should_analyze_image(upload)
      return false if upload.blank?
      return true if Filter.filter_upload(Upload.where(id: upload), max_retry_times: -1).count > 0
      true
    end

    def should_analyze_post(post)
      return false if post.blank? || post.id.blank?
      return true if Filter.filter_post(Post.where(id: post)).count > 0
      false
    end

    def extract_images(uploads)
      Filter
        .filter_upload(uploads)
        .map do |u|
          url = extract_image_url(u)
          { id: u.id, sha1: u.original_sha1 || u.sha1, url: url }
        end
    end

    def extract_image_url(upload)
      if SiteSetting.image_enhancement_analyze_image_base64_encoded
        url = image_to_base64(upload)
      else
        url = UrlHelper.cook_url(upload.url, secure: upload.secure)
        url = Upload.signed_url_from_secure_uploads_url(url) if Upload.secure_uploads_url?(url)
      end
      url
    end

    def build_query_body(images)
      body = {}
      body[:images] = images
      body[:ocr] = @analyze_ocr
      body[:embedding] = @analyze_embedding
      MultiJson.dump(body)
    end

    def build_query_headers(uri, query_body)
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

    def check_for_flag(post)
      return unless @auto_flag_ocr
      ocr_text = ImageSearchData.find_by_post(post).pluck(:ocr_text).join("\n")
      if ocr_text.present? && WordWatcher.new(ocr_text).should_flag?
        PostActionCreator.create(Discourse.system_user, post, :inappropriate, reason: :watched_word)
      end
    end

    def self.analyze_images(image_info)
      self.new.analyze_images(image_info)
    end

    def image_to_base64(upload)
      original_path = Discourse.store.path_for(upload)
      if original_path.blank?
        # download is protected with a DistributedMutex
        fp = Discourse.store.download_safe(upload)
      else
        fp = File.open(original_path, "rb")
      end

      begin
        base64_data = Base64.strict_encode64(fp.read)
        "data:image/#{upload.extension};base64,#{base64_data}"
      ensure
        fp.close if fp
      end
    end
  end
end
