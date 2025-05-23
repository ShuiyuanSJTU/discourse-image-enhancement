# frozen_string_literal: true

require "rails_helper"

describe DiscourseImageEnhancement::ImageSearch do
  before do
    api_endpoint = "https://api.example.com/"
    SiteSetting.image_enhancement_enabled = true
    SiteSetting.image_search_enabled = true
    SiteSetting.image_enhancement_analyze_service_endpoint = api_endpoint
  end

  describe "can search image" do
    let(:image_upload1) { Fabricate(:upload, sha1: "sha1_1") }
    let(:image_upload2) { Fabricate(:upload, sha1: "sha1_2") }
    let!(:image_search_data1) do
      ImageSearchData.create(
        sha1: image_upload1.sha1,
        upload_id: image_upload1.id,
        ocr_text: "car",
        ocr_text_search_data: "'car':2",
        embeddings: Array.new(512) { rand }.to_s,
      )
    end
    let!(:image_search_data2) do
      ImageSearchData.create(
        sha1: image_upload2.sha1,
        upload_id: image_upload2.id,
        ocr_text: "plane",
        ocr_text_search_data: "'plane':2",
        embeddings: Array.new(512) { rand }.to_s,
      )
    end
    let!(:post) do
      Fabricate(:post, topic: Fabricate(:topic), uploads: [image_upload1, image_upload2])
    end

    it "searches using OCR only" do
      search = described_class.new("car", ocr: true, embeddings: false)
      result = search.execute

      expect(result.grouped_results.map(&:image).map(&:id)).to include(image_upload1.id)
      expect(result.grouped_results.map(&:image).map(&:id)).not_to include(image_upload2.id)
    end

    it "searches using embeddings only" do
      SiteSetting.image_enhancement_text_embedding_similarity_threshold = 0
      search = described_class.new("car", ocr: false, embeddings: true)
      allow(DiscourseImageEnhancement::Embedding).to receive(:embed).and_return(
        JSON.parse(image_search_data1.embeddings),
      )
      result = search.execute
      expect(result.grouped_results.map(&:image).map(&:id)).to include(image_upload1.id)
      # most similar image goes first
      expect(result.grouped_results.first.image.id).to eq(image_upload1.id)
    end

    it "searches using both OCR and embeddings" do
      search = described_class.new("plane", ocr: true, embeddings: true)
      allow(DiscourseImageEnhancement::Embedding).to receive(:embed).and_return(
        JSON.parse(image_search_data1.embeddings),
      )
      result = search.execute
      expect(result.grouped_results.map(&:image).map(&:id)).to include(image_upload1.id)
      expect(result.grouped_results.map(&:image).map(&:id)).to include(image_upload2.id)
      expect(result.grouped_results.length).to eq(2)
    end

    it "searches by image" do
      SiteSetting.image_enhancement_image_embedding_similarity_threshold = 0
      file = Rack::Test::UploadedFile.new(file_from_fixtures("logo.png"))
      search = described_class.new(nil, file, ocr: false, embeddings: false, by_image: true)
      allow(DiscourseImageEnhancement::Embedding).to receive(:embed).and_return(
        JSON.parse(image_search_data1.embeddings),
      )
      result = search.execute
      expect(result.grouped_results.map(&:image).map(&:id)).to include(image_upload1.id)
      expect(result.grouped_results.map(&:image).map(&:id)).to include(image_upload2.id)
      expect(result.grouped_results.length).to eq(2)
    end
  end
end
