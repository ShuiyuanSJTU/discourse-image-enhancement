# frozen_string_literal: true

class AddRetryTimesToImageSearchData < ActiveRecord::Migration[7.2]
  def up
    add_column :image_search_data, :retry_times, :integer, default: 0, null: false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
