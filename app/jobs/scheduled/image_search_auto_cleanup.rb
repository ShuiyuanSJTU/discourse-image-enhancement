# frozen_string_literal: true

module Jobs
  class ImageSearchAutoCleanup < ::Jobs::Scheduled
    every 3.days

    def cleanup_image_search_data
      ::DiscourseImageEnhancement::Filter.image_search_data_need_remove.destroy_all
    end

    def execute(_args)
      return unless SiteSetting.image_enhancement_enabled && SiteSetting.image_search_enabled
      cleanup_image_search_data
    end
  end
end
