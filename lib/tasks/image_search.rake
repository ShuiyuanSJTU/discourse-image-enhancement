# frozen_string_literal: true
desc "Generates image search data"
task "image-enhancement:search:backfill", [:start_post] => [:environment] do |_, args|
  backfill_posts = ::DiscourseImageEnhancement::Filter.posts_need_analysis.distinct
  backfill_posts.find_each(order: :desc) do |post|
    DiscourseImageEnhancement::ImageAnalysis.new(auto_flag_ocr: false).process_post(post)
    print "."
  end
end
