# frozen_string_literal: true

RSpec.describe ::ImageEnhancementController do
  fab!(:user)

  let(:search_result) { ::DiscourseImageEnhancement::ImageSearch::ImageSearchResult.new([], []) }

  let(:image_search) do
    Struct.new(:search_result) { def execute = search_result }.new(search_result)
  end

  before do
    SiteSetting.image_enhancement_enabled = true
    SiteSetting.image_search_enabled = true
    api_endpoint = "https://api.example.com/"
    SiteSetting.image_enhancement_analyze_service_endpoint = api_endpoint
    WebMock.stub_request(:post, URI.join(api_endpoint, "text_embedding/")).to_return(
      body: { embedding: Array.new(512) { rand }, success: true }.to_json,
    )
  end

  describe "#index" do
    context "when the user is logged in" do
      before { sign_in(user) }

      it "handles image search page" do
        get "/image-search.json"

        expect(response.status).to eq(200)
      end
    end

    context "when the user is anonymous" do
      it "requires login" do
        get "/image-search.json"

        expect(response.status).to eq(403)
      end
    end

    context "when image search is disabled" do
      before do
        sign_in(user)
        SiteSetting.image_search_enabled = false
      end

      it "returns not found" do
        get "/image-search.json"

        expect(response.status).to eq(404)
      end
    end
  end

  describe "#search" do
    context "when the user is logged in" do
      before { sign_in(user) }

      it "returns results" do
        ::DiscourseImageEnhancement::ImageSearch.stubs(:new).returns(image_search)

        get "/image-search/search.json", params: { term: "term" }

        expect(response.status).to eq(200)
      end

      it "returns 400 if term is missing" do
        get "/image-search/search.json"

        expect(response.status).to eq(400)
      end

      it "invokes ImageSearch when get" do
        ::DiscourseImageEnhancement::ImageSearch
          .expects(:new)
          .with("term", nil, has_entries(ocr: false, embeddings: true))
          .returns(image_search)

        get "/image-search/search.json", params: { term: "term", ocr: "false" }
      end

      it "invokes ImageSearch when post" do
        ::DiscourseImageEnhancement::ImageSearch
          .expects(:new)
          .with("term", nil, has_entries(ocr: false, embeddings: true))
          .returns(image_search)

        post "/image-search/search.json", params: { term: "term", ocr: "false" }
      end

      it "searches by image" do
        file = Rack::Test::UploadedFile.new(file_from_fixtures("logo.png"))
        file.content_type = "image/png"
        ::DiscourseImageEnhancement::ImageSearch
          .expects(:new)
          .with(
            "",
            instance_of(ActionDispatch::Http::UploadedFile),
            has_entries(ocr: false, embeddings: false, by_image: true),
          )
          .returns(image_search)

        post "/image-search/search.json",
             params: {
               term: "",
               image: file,
               ocr: "false",
               embed: "false",
             }
      end
    end

    context "when the user is anonymous" do
      it "requires login" do
        ::DiscourseImageEnhancement::ImageSearch.expects(:new).never

        get "/image-search/search.json", params: { term: "term" }

        expect(response.status).to eq(403)
      end
    end

    context "when image search is disabled" do
      before do
        sign_in(user)
        SiteSetting.image_search_enabled = false
      end

      it "returns not found" do
        ::DiscourseImageEnhancement::ImageSearch.expects(:new).never

        get "/image-search/search.json", params: { term: "term" }

        expect(response.status).to eq(404)
      end
    end

    context "when the user is rate limited" do
      before do
        sign_in(user)
        RateLimiter.enable
        SiteSetting.rate_limit_search_user = 1
      end

      it "returns too many requests" do
        ::DiscourseImageEnhancement::ImageSearch.expects(:new).once.returns(image_search)

        get "/image-search/search.json", params: { term: "term" }

        expect(response.status).to eq(200)

        get "/image-search/search.json", params: { term: "term" }

        expect(response.status).to eq(429)
      end
    end
  end
end
