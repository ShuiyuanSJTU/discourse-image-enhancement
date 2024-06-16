# frozen_string_literal: true

module Jobs
  module DiscourseImageEnhancement
    class AutoCleanup < ::Jobs::Scheduled
      every 3.days

      def cleanup_image_search_data
        ::DiscourseImageEnhancement::Filter.image_search_data_need_remove.destroy_all
      end

      def cleanup_failed_count
        failed_count = PluginStore.get(::DiscourseImageEnhancement::PLUGIN_NAME, "failed_count")
        return unless failed_count.present?
        # Set max_retry_times to -1 to ignore the max_retry_times limit
        # if a sha1 is failed_count but not in the filtered result, means it will not affect the upload selection
        # so we will remove it from the failed_count
        failed_records_should_keep = ::DiscourseImageEnhancement::Filter.filter_upload(
          Upload.where("COALESCE(original_sha1, sha1) IN ?", failed_count.keys),
          max_retry_times: -1
        ).select("COALESCE(original_sha1, sha1) as _sha1").pluck("_sha1")
        failed_count = failed_count.select { |k, _| failed_records_should_keep.include?(k) }
        PluginStore.set(::DiscourseImageEnhancement::PLUGIN_NAME, "failed_count", failed_count)
      end


      def execute(_args)
        return unless SiteSetting.image_enhancement_enabled && SiteSetting.image_search_enabled
        cleanup_failed_count
        cleanup_image_search_data
      end
    end
  end
end
