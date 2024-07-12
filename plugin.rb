# frozen_string_literal: true

# name: discourse-image-enhancement
# about: An AI-powered plugin for Discourse that provides image analysis and search.
# meta_topic_id: TODO
# version: 0.1.1
# authors: pangbo
# url: https://github.com/ShuiyuanSJTU/discourse-image-enhancement
# required_version: 2.7.0

enabled_site_setting :image_enhancement_enabled

register_asset "stylesheets/common/discourse-image-enhancement.scss"

module ::DiscourseImageEnhancement
  PLUGIN_NAME ||= "discourse-image-enhancement".freeze
end

Rails.autoloaders.main.push_dir(File.join(__dir__, "lib"), namespace: ::DiscourseImageEnhancement)

require_relative "lib/engine"

after_initialize do
  module ::DiscourseImageEnhancement
    module OverridePullHotlinkedImages
      def execute(args)
        super(args)
        if SiteSetting.image_enhancement_enabled
          Jobs.enqueue(:post_image_enhance_process, post_id: args[:post_id])
        end
      end
    end
    ::Jobs::PullHotlinkedImages.prepend OverridePullHotlinkedImages
  end
end
