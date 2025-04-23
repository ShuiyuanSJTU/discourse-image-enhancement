# frozen_string_literal: true

module Jobs
  class ImageSearchAutoBackfill < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      return unless SiteSetting.image_enhancement_enabled && SiteSetting.image_search_enabled
      start_time = Time.now
      failed_post_count = 0
      while Time.now - start_time < 50.minutes && failed_post_count < 50
        backfill_posts_id =
          ::DiscourseImageEnhancement::Filter
            .posts_need_analysis
            .order(id: :desc)
            .limit(100)
            .pluck(:id)
        no_more = backfill_posts_id.count < 100
        backfill_posts_id.each do |post_id|
          break if Time.now - start_time > 50.minutes
          analyzer = ::DiscourseImageEnhancement::ImageAnalysis.new(auto_flag_ocr: false)
          post = Post.find_by(id: post_id)
          result = analyzer.process_post(post)
          failed_post_count += 1 if result.nil?
        end
        # break the while loop, all lefts are failed posts, ignore them
        break if no_more
      end
      if failed_post_count >= 50
        Rails.logger.warn("Failed to backfill images for 50 posts in 50 minutes, skipping the rest")
      end
    end
  end
end
