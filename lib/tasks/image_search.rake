desc "Generates image search data"
task "image-enhancement:search:backfill", [:start_post] => [:environment] do |_, args|
  backfill_posts = ::DiscourseImageEnhancement::ImageSearch.Filter
    .posts_need_analysis
    .distinct
  backfill_posts.find_each(order: :desc) do |post|
    DiscourseImageEnhancement::ImageAnalysis.process_post(post)
    print "."
  end
end