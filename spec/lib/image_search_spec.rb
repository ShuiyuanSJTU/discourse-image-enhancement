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

    it "filters posts by guardian category access", :aggregate_failures do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      shared_upload = Fabricate(:upload, sha1: "shared_sha1")
      ImageSearchData.create(
        sha1: shared_upload.sha1,
        upload_id: shared_upload.id,
        ocr_text: "securetoken",
        ocr_text_search_data: "'securetoken':1",
        embeddings: Array.new(512) { rand }.to_s,
      )
      public_post = Fabricate(:post, topic: Fabricate(:topic), uploads: [shared_upload])
      private_post =
        Fabricate(
          :post,
          topic: Fabricate(:topic, category: private_category),
          uploads: [shared_upload],
        )
      user = Fabricate(:user)
      member = Fabricate(:user).tap { |group_member| group.add(group_member) }

      public_result =
        described_class.new(
          "securetoken",
          ocr: true,
          embeddings: false,
          guardian: Guardian.new(user),
        ).execute
      member_result =
        described_class.new(
          "securetoken",
          ocr: true,
          embeddings: false,
          guardian: Guardian.new(member),
        ).execute

      expect(public_result.grouped_results.map(&:post).map(&:id)).to contain_exactly(public_post.id)
      expect(member_result.grouped_results.map(&:post).map(&:id)).to contain_exactly(
        private_post.id,
        public_post.id,
      )
    end
  end
end
