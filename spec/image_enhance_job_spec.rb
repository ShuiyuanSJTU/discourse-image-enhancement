# frozen_string_literal: true

require "rails_helper"

describe ::Jobs::PostImageEnhanceProcess do
  before do
    Jobs.run_immediately!
    SiteSetting.image_enhancement_enabled = true
  end

  let(:post) { Fabricate(:post) }
  let(:user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }

  it "should trigger job on rebake" do
    ::Jobs::PostImageEnhanceProcess.any_instance.expects(:execute).once
    post.rebake!
  end

  it "should trigger job on create" do
    ::Jobs::PostImageEnhanceProcess.any_instance.expects(:execute).once
    PostCreator.create(
      user,
      raw: "test a random topic",
      title: "this is a topic",
      category: category.id,
      skip_guardian: true,
      skip_validations: true,
    )
  end

  it "should not trigger job" do
    SiteSetting.image_enhancement_enabled = false
    ::Jobs::PostImageEnhanceProcess.any_instance.expects(:execute).never
    post.rebake!
  end
end

describe ::Jobs::ImageSearchAutoBackfill do
  before do
    SiteSetting.image_enhancement_enabled = true
    SiteSetting.image_search_enabled = true
    SiteSetting.image_enhancement_max_images_per_post = 3
    SiteSetting.image_enhancement_max_retry_times_per_image = 3
  end

  let(:image_upload1) { Fabricate(:upload) }
  let(:post) { Fabricate(:post, uploads: [image_upload1]) }

  it "should invoke process_post" do
    ::DiscourseImageEnhancement::ImageAnalysis.expects(:process_post).with(post).once
    described_class.new.execute({})
  end

  it "should ignore failed posts" do
    PluginStore.set("discourse-image-enhancement", "failed_count", { image_upload1.sha1 => 4 })
    ::DiscourseImageEnhancement::ImageAnalysis.expects(:process_post).never
    described_class.new.execute({})
  end
end

describe ::Jobs::ImageSearchAutoCleanup do
  before do
    SiteSetting.image_enhancement_enabled = true
    SiteSetting.image_search_enabled = true
    SiteSetting.image_enhancement_max_images_per_post = 3
    SiteSetting.image_enhancement_max_retry_times_per_image = 3
  end

  let(:image_search_data) { ImageSearchData.create(sha1: "1234") }
  let(:image_upload) { Fabricate(:upload, sha1: image_search_data.sha1) }
  let(:post) { Fabricate(:post, uploads: [image_upload]) }

  it "should not cleanup image_search_data" do
    post
    described_class.new.execute({})
    expect(ImageSearchData.find_by(sha1: "1234")).to eq(image_search_data)
  end

  it "should cleanup orphaned image_search_data" do
    image_search_data
    described_class.new.execute({})
    expect(ImageSearchData.find_by(sha1: "1234")).to eq(nil)
  end

  it "should cleanup image_search_data in restricted category" do
    post.topic.category.update!(read_restricted: true)
    described_class.new.execute({})
    expect(ImageSearchData.find_by(sha1: "1234")).to eq(nil)
  end

  it "should cleanup orphaned failed_count" do
    PluginStore.set(
      "discourse-image-enhancement",
      "failed_count",
      { image_upload.sha1 => 4, "5678" => 100 },
    )
    image_upload
    image_search_data.destroy
    described_class.new.execute({})
    expect(PluginStore.get("discourse-image-enhancement", "failed_count")).to eq(
      { image_upload.sha1 => 4 },
    )
  end

  it "should cleanup failed_count for already processed images" do
    PluginStore.set("discourse-image-enhancement", "failed_count", { image_upload.sha1 => 4 })
    described_class.new.execute({})
    expect(PluginStore.get("discourse-image-enhancement", "failed_count")).to eq({})
  end
end
