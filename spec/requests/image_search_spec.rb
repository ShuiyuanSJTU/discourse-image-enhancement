# frozen_string_literal: true

describe ::ImageEnhancementController do
  before do
    SiteSetting.image_enhancement_enabled = true
    SiteSetting.image_search_enabled = true
  end

  it "handles image search page" do
    get "/image-search.json"
    expect(response.status).to eq(200)
  end

  context "when user try to search image" do
    it "should return 200" do
      get "/image-search/search.json", params: { term: "term" }
      expect(response.status).to eq(200)
    end

    it "should return 400 if term is missing" do
      get "/image-search/search.json"
      expect(response.status).to eq(400)
    end

    it "should invoke ImageSearch" do
      ::DiscourseImageEnhancement::ImageSearch.expects(:new).with(
        "term",
        has_entries(ocr: false, description: true),
      )
      get "/image-search/search.json", params: { term: "term", ocr: "false" }
    end
  end
end
