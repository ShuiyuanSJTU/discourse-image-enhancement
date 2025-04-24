# frozen_string_literal: true

class AddRetryTimesToImageSearchData < ActiveRecord::Migration[7.2]
  def change
    add_column :image_search_data, :retry_times, :integer, default: 0, null: false
  end
end
