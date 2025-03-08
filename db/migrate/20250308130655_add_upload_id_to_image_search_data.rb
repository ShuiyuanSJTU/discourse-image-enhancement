# frozen_string_literal: true
class AddUploadIdToImageSearchData < ActiveRecord::Migration[7.2]
  def up
    add_column :image_search_data, :upload_id, :integer

    remove_index :image_search_data, :sha1
    remove_index :image_search_data, :ocr_text_search_data
    remove_index :image_search_data, :description_search_data

    execute <<~SQL.squish
    INSERT INTO image_search_data (sha1, ocr_text, description, ocr_text_search_data, description_search_data, upload_id)
    SELECT i.sha1, i.ocr_text, i.description, i.ocr_text_search_data, i.description_search_data, u.id
    FROM uploads u
    INNER JOIN image_search_data i ON COALESCE(u.original_sha1, u.sha1) = i.sha1
    SQL

    execute "DELETE FROM image_search_data WHERE upload_id IS NULL"
    change_column_null :image_search_data, :upload_id, false

    add_index :image_search_data, :sha1
    add_index :image_search_data, :upload_id, unique: true
    add_index :image_search_data, :ocr_text_search_data, using: "gin"
    add_index :image_search_data, :description_search_data, using: "gin"
    add_foreign_key :image_search_data, :uploads, on_delete: :cascade
  end

  def down
    remove_foreign_key :image_search_data, :uploads

    execute <<~SQL.squish
      INSERT INTO image_search_data (sha1, ocr_text, description, ocr_text_search_data, description_search_data)
      SELECT DISTINCT ON (sha1) sha1, ocr_text, description, ocr_text_search_data, description_search_data
      FROM image_search_data
      WHERE upload_id IS NOT NULL
    SQL

    remove_column :image_search_data, :upload_id

    remove_index :image_search_data, :sha1
    add_index :image_search_data, :sha1, unique: true
  end
end
