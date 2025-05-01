# frozen_string_literal: true

describe ::ImageEnhancementController do
  before do
    SiteSetting.image_enhancement_enabled = true
    SiteSetting.image_search_enabled = true
    api_endpoint = "https://api.example.com/"
    SiteSetting.image_enhancement_analyze_service_endpoint = api_endpoint
    WebMock.stub_request(:post, URI.join(api_endpoint, "text_embedding/")).to_return(
      body: { embedding: Array.new(512) { rand }, success: true }.to_json,
    )
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

    it "should invoke ImageSearch when get" do
      ::DiscourseImageEnhancement::ImageSearch.expects(:new).with(
        "term",
        nil,
        has_entries(ocr: false, embeddings: true),
      )
      get "/image-search/search.json", params: { term: "term", ocr: "false" }
    end

    it "should invoke ImageSearch when post" do
      ::DiscourseImageEnhancement::ImageSearch.expects(:new).with(
        "term",
        nil,
        has_entries(ocr: false, embeddings: true),
      )
      post "/image-search/search.json", params: { term: "term", ocr: "false" }
    end

    it "could search by image" do
      file = Rack::Test::UploadedFile.new(file_from_fixtures("logo.png"))
      file.content_type = "image/png"
      ::DiscourseImageEnhancement::ImageSearch.expects(:new).with(
        "",
        instance_of(ActionDispatch::Http::UploadedFile),
        has_entries(ocr: false, embeddings: false, by_image: true),
      )
      post "/image-search/search.json",
           params: {
             term: "",
             image: file,
             ocr: "false",
             embed: "false",
           }
    end
  end
end
