# frozen_string_literal: true

require "rails_helper"

describe DiscourseImageEnhancement::ImageAnalysis do
  before(:example) do
    SiteSetting.image_enhancement_analyze_ocr_enabled = true
    SiteSetting.image_enhancement_analyze_description_enabled = true
    SiteSetting.image_enhancement_analyze_embedding_enabled = true
  end

  let(:image_upload) { Fabricate(:upload, sha1: "1234") }

  describe "save search data" do
    it "can save data in english" do
      SiteSetting.default_locale = "en"
      image = {
        sha1: "1234",
        ocr_result: ["a car", "a man"],
        description: "a flying car",
        embedding: Array.new(512) { rand },
        success: true,
      }
      described_class.new.save_analyzed_image_data(image, image_upload)
      expect(ImageSearchData.find_by(sha1: "1234").upload_id).to eq(image_upload.id)
      expect(ImageSearchData.find_by(sha1: "1234").ocr_text).to eq("a car\na man")
      expect(ImageSearchData.find_by(sha1: "1234").description_search_data).to eq("'car':3 'fli':2")
      expect(ImageSearchData.find_by(sha1: "1234").embeddings).to be_present
    end

    it "can save data in chinese" do
      SiteSetting.default_locale = "zh_CN"
      image = {
        sha1: "1234",
        ocr_result: %w[一辆车 天空],
        description: "一辆飞行的汽车",
        embedding: Array.new(512) { rand },
        success: true,
      }
      described_class.new.save_analyzed_image_data(image, image_upload)
      expect(ImageSearchData.find_by(sha1: "1234").upload_id).to eq(image_upload.id)
      expect(ImageSearchData.find_by(sha1: "1234").ocr_text).to eq("一辆车\n天空")
      expect(ImageSearchData.find_by(sha1: "1234").description_search_data).to be_present
      expect(ImageSearchData.find_by(sha1: "1234").embeddings).to be_present
    end
  end

  describe "can extract images" do
    it "can extract local images from post" do
      upload = Fabricate(:image_upload)
      post = Fabricate(:post, raw: "![image1](#{upload.short_url})", uploads: [upload])
      extracted_info = described_class.new.extract_images(post.uploads)
      expect(extracted_info.first[:sha1]).to eq(upload.sha1)
    end
    it "can extract secure images from post" do
      setup_s3
      stub_s3_store
      SiteSetting.secure_uploads = true
      upload = Fabricate(:secure_upload_s3)
      post = Fabricate(:post, raw: "![image1](#{upload.short_url})", uploads: [upload])
      extracted_info = described_class.new.extract_images(post.uploads)
      expect(extracted_info.first[:sha1]).to eq(upload.original_sha1)
    end
  end

  describe "can flag post" do
    fab!(:image_upload)
    it "can check watched words" do
      SiteSetting.image_enhancement_auto_flag_ocr = true
      WatchedWord.create_or_update_word(word: "car", action: WatchedWord.actions[:flag])
      result = {
        images: [
          {
            sha1: image_upload.sha1,
            ocr_result: ["a car", "another car"],
            description: "a flying car",
            embedding: Array.new(512) { rand },
            success: true,
          },
        ],
      }
      post = Fabricate(:post, raw: "![image1](#{image_upload.short_url})", uploads: [image_upload])
      result[:images].each do |image|
        described_class.new.save_analyzed_image_data(image, image_upload)
      end

      PostActionCreator.expects(:create).once
      described_class.new.check_for_flag(post)
    end
  end

  describe "can analyze post" do
    fab!(:image_upload)
    before(:example) do
      api_endpoint = "https://api.example.com/"
      SiteSetting.image_enhancement_enabled = true
      SiteSetting.image_enhancement_analyze_service_endpoint = api_endpoint
      SiteSetting.default_locale = "en"
      WebMock.stub_request(:post, URI.join(api_endpoint, "analyze/")).to_return(
        body: {
          images: [
            {
              sha1: image_upload.sha1,
              ocr_result: ["a car"],
              description: "a flying car",
              embedding: Array.new(512) { rand },
              success: true,
            },
          ],
        }.to_json,
      )
      WebMock.stub_request(:post, URI.join(api_endpoint, "text_embedding/")).to_return(
        body: { embedding: Array.new(512) { rand }, success: true }.to_json,
      )
    end
    it "can analyze post" do
      post =
        Fabricate(
          :post,
          raw: "![image1](#{image_upload.short_url})",
          uploads: [image_upload],
          topic: Fabricate(:topic, category: Fabricate(:category)),
        )
      described_class.new.process_post(post)
      expect(ImageSearchData.find_by(sha1: image_upload.sha1).ocr_text).to eq("a car")
    end
  end
end
