# frozen_string_literal: true
class CreateImageSearchData < ActiveRecord::Migration[6.0]
  def up
    create_table :image_search_data, id: false do |t|
      t.string :sha1, null: false
      t.text :ocr_text
      t.text :description
      t.tsvector :ocr_text_search_data
      t.tsvector :description_search_data
    end

    add_index :image_search_data, :sha1, unique: true
    add_index :image_search_data, :ocr_text_search_data, using: "gin"
    add_index :image_search_data, :description_search_data, using: "gin"
  end

  def down
    drop_table :image_search_data
  end
end
