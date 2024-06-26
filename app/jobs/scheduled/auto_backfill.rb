# frozen_string_literal: true

module Jobs
  module DiscourseImageEnhancement
    class AutoBackfill < ::Jobs::Scheduled
      every 1.hour

      def execute(_args)
        return unless SiteSetting.image_enhancement_enabled && SiteSetting.image_search_enabled
        start_time = Time.now
        backfill_posts = ::DiscourseImageEnhancement::Filter
          .posts_need_analysis
          .distinct
        backfill_posts.find_each(order: :desc) do |post|
          break if Time.now - start_time > 50.minutes
          ::DiscourseImageEnhancement::ImageAnalysis.process_post(post)
        end
      end
    end
  end
end
