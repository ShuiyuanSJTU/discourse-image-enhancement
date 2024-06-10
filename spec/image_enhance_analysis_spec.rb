# frozen_string_literal: true

require "rails_helper"

describe DiscourseImageEnhancement::ImageAnalysis do
  before(:example) { }

  describe 'save search data' do
    it 'can save data in english' do
      SiteSetting.default_locale = 'en'
      image = {"sha1"=>"1234", "ocr_text"=>"a car", "description"=>"a flying car"}
      DiscourseImageEnhancement::ImageAnalysis.save_analyzed_image_data(image)
      expect(ImageSearchData.find_by(sha1: "1234").ocr_text).to eq("a car")
      expect(ImageSearchData.find_by(sha1: "1234").description_search_data).to eq("'car':3 'fli':2")
    end

    it 'can save data in chinese' do
      # SiteSetting.default_locale = 'zh_CN'
      # image = {"sha1"=>"1234", "ocr_text"=>"一辆车", "description"=>"一辆飞行的汽车"}
      # DiscourseImageEnhancement::ImageAnalysis.save_analyzed_image_data(image)
      # expect(ImageSearchData.find_by(sha1: "1234").ocr_text).to eq("一辆车")
      # expect(ImageSearchData.find_by(sha1: "1234").description_search_data).to eq("'一辆':1 '汽车':3 '飞行':2")
    end
  end

  describe 'can extract images' do
    it 'can extract local images from post' do
      upload = Fabricate(:image_upload)
      post = Fabricate(:post, raw: "![image1](#{upload.short_url})", uploads: [upload])
      extracted_info = DiscourseImageEnhancement::ImageAnalysis.extract_images(post)
      expect(extracted_info.first[:sha1]).to eq(upload.sha1)
    end
    it 'can extract secure images from post' do
      setup_s3
      stub_s3_store
      SiteSetting.secure_uploads = true
      upload = Fabricate(:secure_upload_s3)
      post = Fabricate(:post, raw: "![image1](#{upload.short_url})", uploads: [upload])
      extracted_info = DiscourseImageEnhancement::ImageAnalysis.extract_images(post)
      expect(extracted_info.first[:sha1]).to eq(upload.original_sha1)
    end
  end

  describe 'can analyze post' do
    fab!(:image_upload)
    before(:example) do
      api_endpoint = "https://api.example.com/analyze_image"
      SiteSetting.image_enhancement_enabled = true
      SiteSetting.image_enhancement_analyze_service_endpoint = api_endpoint
      SiteSetting.default_locale = 'en'
      WebMock.stub_request(:post, api_endpoint).to_return(
        body: {"images":[{sha1: image_upload.sha1, ocr_text: "a car", description: "a flying car"}]}.to_json
      )
    end
    it 'can analyze post' do
      post = Fabricate(:post, raw: "![image1](#{image_upload.short_url})", uploads: [image_upload])
      # byebug
      # DiscourseImageEnhancement::ImageAnalysis.expects(:build_query_body).once
      # Faraday::Connection.any_instance.expects(:post).once
      DiscourseImageEnhancement::ImageAnalysis.process_post(post)
      expect(ImageSearchData.find_by(sha1: image_upload.sha1).ocr_text).to eq("a car")
    end
  end
end
