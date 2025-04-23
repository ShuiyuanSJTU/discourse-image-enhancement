# frozen_string_literal: true
class AddEmbeddingsColumn < ActiveRecord::Migration[7.2]
  def change
    enable_extension :vector
    add_column :image_search_data, :embeddings, :halfvec
    execute <<~SQL
      CREATE INDEX IF NOT EXISTS image_search_data_embeddings_index
      ON image_search_data
      USING hnsw ((binary_quantize(embeddings)::bit(512)) bit_hamming_ops);
    SQL
  end
end
