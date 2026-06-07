# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseImageEnhancement::Embedding do
  before do
    Discourse.cache.clear
    SiteSetting.image_enhancement_analyze_service_endpoint = "https://api.example.com/"
  end

  it "raises a generic external service error when the embedding request fails" do
    WebMock.stub_request(:post, "https://api.example.com/text_embedding/").to_return(
      status: 500,
      body: "secret upstream details",
    )

    expect { described_class.embed("term") }.to raise_error(
      DiscourseImageEnhancement::ExternalServiceError,
      "Failed to generate embedding",
    )
  end

  it "raises a generic external service error when the embedding response is malformed" do
    WebMock.stub_request(:post, "https://api.example.com/text_embedding/").to_return(
      body: "not-json",
    )

    expect { described_class.embed("malformed") }.to raise_error(
      DiscourseImageEnhancement::ExternalServiceError,
      "Failed to generate embedding",
    )
  end
end
