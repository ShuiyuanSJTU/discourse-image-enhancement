module ::Jobs
  class PostImageEnhanceProcess < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      post_id = args[:post_id]
      post = Post.find_by(id: post_id)
      return unless post

      if SiteSetting.image_enhancement_enabled
        ::DiscourseImageEnhancement::ImageAnalysis.process_post(post)
        ::DiscourseImageEnhancement::ImageAnalysis.check_for_flag(post)
      end
    end
  end
end