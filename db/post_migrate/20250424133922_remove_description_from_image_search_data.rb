# frozen_string_literal: true

class RemoveDescriptionFromImageSearchData < ActiveRecord::Migration[7.2]
  def up
    remove_index :image_search_data, name: "index_image_search_data_on_description_search_data"
    remove_column :image_search_data, :description
    remove_column :image_search_data, :description_search_data
  end

  def down
    unless column_exists?(:image_search_data, :description)
      add_column :image_search_data, :description, :text
    end
    unless column_exists?(:image_search_data, :description_search_data)
      add_column :image_search_data, :description_search_data, :tsvector
    end
    unless index_exists?(:image_search_data, :description_search_data)
      add_index :image_search_data,
                :description_search_data,
                using: :gin,
                name: "index_image_search_data_on_description_search_data"
    end
  end
end
