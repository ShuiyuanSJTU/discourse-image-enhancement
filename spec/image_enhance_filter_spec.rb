# frozen_string_literal: true

require "rails_helper"

describe DiscourseImageEnhancement::Filter do
  before do 
    SiteSetting.image_enhancement_enabled = true
    SiteSetting.image_search_enabled = true
    SiteSetting.image_enhancement_max_image_size_kb = 1024
    SiteSetting.image_enhancement_min_image_width = 100
    SiteSetting.image_enhancement_min_image_height = 100
    SiteSetting.image_enhancement_max_retry_times_per_image = 3
  end
    
  let(:post) { Fabricate(:post) }
  let(:user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }

  describe 'can filter uploads' do
    before {}
    
    let(:image_upload1) { Fabricate(:upload) }
    let(:image_upload2) { Fabricate(:upload) }

    it 'can filter uploads by width and height' do
      image_upload1.update!(width: 150, height: 150)
      image_upload2.update!(width: 50, height: 50)
      uploads = DiscourseImageEnhancement::Filter.filter_upload(Upload.where(id: [image_upload1.id, image_upload2.id]))
      expect(uploads).to eq([image_upload1])
    end

    it 'can filter uploads by file size' do
      image_upload1.update!(filesize: 2048.kilobytes)
      image_upload2.update!(filesize: 1024.kilobytes)
      uploads = DiscourseImageEnhancement::Filter.filter_upload(Upload.where(id: [image_upload1.id, image_upload2.id]))
      expect(uploads).to eq([image_upload2])
    end

    it 'can filter uploads by file type' do
      image_upload1.update!(original_filename: 'image1.jpeg')
      image_upload2.update!(original_filename: 'image2.gif')
      uploads = DiscourseImageEnhancement::Filter.filter_upload(Upload.where(id: [image_upload1.id, image_upload2.id]))
      expect(uploads).to eq([image_upload1])
    end

    it 'can exclude existing uploads' do
      image_upload1.update!(original_sha1: '1234')
      image_upload2.update!(original_sha1: '5678')
      ImageSearchData.create(sha1: '1234')
      uploads = DiscourseImageEnhancement::Filter.filter_upload(Upload.where(id: [image_upload1.id, image_upload2.id]))
      expect(uploads).to eq([image_upload2])
      uploads = DiscourseImageEnhancement::Filter.filter_upload(Upload.where(id: [image_upload1.id, image_upload2.id]), exclude_existing: false)
      expect(uploads).to eq([image_upload1, image_upload2])
    end

    it 'can filter uploads by max retry times' do
      PluginStore.set('discourse-image-enhancement', "failed_count", {image_upload1.sha1 => 4, image_upload2.sha1 => 2})
      uploads = DiscourseImageEnhancement::Filter.filter_upload(Upload.where(id: [image_upload1.id, image_upload2.id]))
      expect(uploads).to eq([image_upload2])
      uploads = DiscourseImageEnhancement::Filter.filter_upload(Upload.where(id: [image_upload1.id, image_upload2.id]), max_retry_times: -1)
      expect(uploads).to eq([image_upload1, image_upload2])
    end
  end

  describe "can filter image_search_data_need_remove" do
    before {}
    let(:image_upload1) { Fabricate(:upload) }
    let(:image_upload2) { Fabricate(:upload) }
    let!(:post) { Fabricate(:post, uploads: [image_upload1, image_upload2]) }
    let!(:image_search_data1) { ImageSearchData.create(sha1: image_upload1.sha1) }
    let!(:image_search_data2) { ImageSearchData.create(sha1: image_upload2.sha1) }

    it 'should not remove normal data' do
      expect(ImageSearchData.count).to eq(2)
      expect(DiscourseImageEnhancement::Filter.image_search_data_need_remove).to eq([])
    end

    it 'should remove data without uploads' do
      image_upload2.destroy
      expect(DiscourseImageEnhancement::Filter.image_search_data_need_remove).to eq([image_search_data2])
    end

    it 'should remove data without posts' do
      post.destroy
      expect(DiscourseImageEnhancement::Filter.image_search_data_need_remove).to eq([image_search_data1, image_search_data2])
    end

    it 'should ignore max_retry_times' do
      PluginStore.set('discourse-image-enhancement', "failed_count", {image_upload1.sha1 => 4, image_upload2.sha1 => 100})
      expect(DiscourseImageEnhancement::Filter.image_search_data_need_remove).to eq([])
    end
  end
end
