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

  it 'should trigger job on rebake' do
    ::Jobs::PostImageEnhanceProcess.any_instance.expects(:execute).once
    post.rebake!
  end

  it 'should trigger job on create' do
    ::Jobs::PostImageEnhanceProcess.any_instance.expects(:execute).once
    PostCreator.create(user, raw: "test a random topic", title: "this is a topic", category: category.id, skip_guardian: true, skip_validations: true)
  end

  it 'should not trigger job' do
    SiteSetting.image_enhancement_enabled = false
    ::Jobs::PostImageEnhanceProcess.any_instance.expects(:execute).never
    post.rebake!
  end
end
