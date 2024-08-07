# frozen_string_literal: true

class ImageSearchData < ActiveRecord::Base
  self.primary_key = :sha1

  def self.find_by_post(post)
    self.where(sha1: post.uploads.pluck("COALESCE(uploads.original_sha1, uploads.sha1)").uniq)
  end
end

# == Schema Information
#
# Table name: image_search_data
#
#  sha1                    :string           not null, primary key
#  ocr_text                :text
#  description             :text
#  ocr_text_search_data    :tsvector
#  description_search_data :tsvector
#
# Indexes
#
#  index_image_search_data_on_description_search_data  (description_search_data) USING gin
#  index_image_search_data_on_ocr_text_search_data     (ocr_text_search_data) USING gin
#  index_image_search_data_on_sha1                     (sha1) UNIQUE
#
