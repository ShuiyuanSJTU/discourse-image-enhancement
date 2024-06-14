desc "Generates image search data"
task "image-enhancement:search:backfill", [:start_post] => [:environment] do |_, args|
    Post.where("id >= ?", args[:start_post].to_i||0).find_each do |post|
        DiscourseImageEnhancement::ImageAnalysis.process_post(post)
        print "."
    end
end