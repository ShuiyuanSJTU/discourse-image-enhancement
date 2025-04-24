# frozen_string_literal: true

class ImageSearchData < ActiveRecord::Base
  belongs_to :uploads
  self.primary_key = :upload_id

  def self.find_by_post(post)
    self.where(upload_id: post.uploads.pluck(:id))
  end
end

# == Schema Information
#
# Table name: image_search_data
#
#  sha1                 :string           not null
#  ocr_text             :text
#  ocr_text_search_data :tsvector
#  upload_id            :integer          not null, primary key
#  embeddings           :halfvec
#
# Indexes
#
#  image_search_data_embeddings_index               (((binary_quantize(embeddings))::bit(512)) bit_hamming_ops) USING hnsw
#  index_image_search_data_on_ocr_text_search_data  (ocr_text_search_data) USING gin
#  index_image_search_data_on_sha1                  (sha1)
#  index_image_search_data_on_upload_id             (upload_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (upload_id => uploads.id) ON DELETE => cascade
#
