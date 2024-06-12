# frozen_string_literal: true

# name: discourse-image-enhancement
# about: TODO
# meta_topic_id: TODO
# version: 0.0.0-dev1
# authors: pangbo
# url: https://github.com/ShuiyuanSJTU/discourse-image-enhancement
# required_version: 2.7.0

enabled_site_setting :image_enhancement_enabled

module ::DiscourseImageEnhancement
  PLUGIN_NAME = "discourse-image-enhancement"
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseImageEnhancement
  end
end

register_asset "stylesheets/common/discourse-image-enhancement.scss"
  
after_initialize do
  require_relative "lib/discourse_image_enhancement.rb"
  require_relative "app/controllers/image_enhancement_controller.rb"
  require_relative "app/models/image_search_data.rb"
  require_relative "app/jobs/regular/post_image_enhance_process.rb"

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

  DiscourseImageEnhancement::Engine.routes.draw do
    get "/image-search" => "image_enhancement#index"
    # define routes here
  end
  
  Discourse::Application.routes.draw { mount ::DiscourseImageEnhancement::Engine, at: "/" }
end
