# frozen_string_literal: true

class ImageSearchData < ActiveRecord::Base
  self.primary_key = :sha1
end