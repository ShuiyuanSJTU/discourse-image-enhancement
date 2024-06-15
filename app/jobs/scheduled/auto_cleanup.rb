# frozen_string_literal: true

module Jobs
  module DiscourseImageEnhancement
    class AutoCleanup < ::Jobs::Scheduled
      every 3.days

      def execute(_args)
        return unless SiteSetting.discourse_image_enhancement_enabled && SiteSetting.image_search_enabled
        ::DiscourseImageEnhancement::Filter.image_search_data_need_remove.destroy_all
      end
    end
  end
end
