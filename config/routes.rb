# frozen_string_literal: true

DiscourseImageEnhancement::Engine.routes.draw do
  get "/image-search" => "image_enhancement#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::DiscourseImageEnhancement::Engine, at: "/" }
