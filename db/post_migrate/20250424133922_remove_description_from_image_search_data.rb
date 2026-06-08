# frozen_string_literal: true

class RemoveDescriptionFromImageSearchData < ActiveRecord::Migration[7.2]
  def up
    remove_index :image_search_data, name: "index_image_search_data_on_description_search_data"
    remove_column :image_search_data, :description
    remove_column :image_search_data, :description_search_data
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
