# frozen_string_literal: true

class ImageSearchResultTopicSerializer < BasicTopicSerializer
  include TopicTagsMixin
  attributes :category_id

  def category_id
    object.category&.id
  end
end