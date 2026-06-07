# frozen_string_literal: true

RSpec.describe ImageSearchData do
  fab!(:upload)

  it "associates with upload using the singular association name" do
    image_search_data = described_class.create!(sha1: upload.sha1, upload_id: upload.id)

    expect(image_search_data.upload).to eq(upload)
    expect(upload.image_search_data).to eq(image_search_data)
  end
end
