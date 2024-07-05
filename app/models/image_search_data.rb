# frozen_string_literal: true

class ImageSearchData < ActiveRecord::Base
  self.primary_key = :sha1

  def self.find_by_post(post)
    self.where(sha1: post.uploads.pluck("COALESCE(uploads.original_sha1, uploads.sha1)").uniq)
  end
end
