# frozen_string_literal: true
desc "Generates image search data"
task "image-enhancement:search:backfill", [:start_post] => [:environment] do |_, args|
  current_upload_id = Upload.select(:id).last.id + 1
  loop do
    batch =
      ::DiscourseImageEnhancement::Filter
        .uploads_need_analysis
        .where("uploads.id < ?", current_upload_id)
        .order(id: :desc)
        .limit(100)
        .to_a
    break if batch.count == 0
    puts "\nProcessing uploads with id #{batch.pluck(:id).min}...#{batch.pluck(:id).max}"
    batch.each do |upload|
      ::DiscourseImageEnhancement::ImageAnalysis.new(auto_flag_ocr: false).process_image(upload)
      print "."
    end
    current_upload_id = batch.pluck(:id).min
  end
end
