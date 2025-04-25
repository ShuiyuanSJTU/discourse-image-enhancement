# frozen_string_literal: true

module Jobs
  class ImageSearchAutoBackfill < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      return unless SiteSetting.image_enhancement_enabled && SiteSetting.image_search_enabled
      start_time = Time.now
      failed_count = 0
      while Time.now - start_time < 50.minutes && failed_count < 50
        backfill_uploads_id =
          ::DiscourseImageEnhancement::Filter
            .uploads_need_analysis
            .joins(:posts)
            .order(posts: { id: :desc })
            .limit(100)
            .pluck("uploads.id")
        no_more = backfill_uploads_id.count < 100
        backfill_uploads_id.each do |upload_id|
          break if Time.now - start_time > 50.minutes
          upload = Upload.find_by(id: upload_id)
          analyzer = ::DiscourseImageEnhancement::ImageAnalysis.new(auto_flag_ocr: false)
          # We use process_image here, which can reuse existing search data
          result = analyzer.process_image(upload)
          failed_count += 1 if result.nil?
        end
        # break the while loop, all lefts are failed posts, ignore them
        break if no_more
      end
      if failed_count >= 50
        Rails.logger.warn("Failed to backfill 50 images in 50 minutes, skipping the rest")
      end
    end
  end
end
