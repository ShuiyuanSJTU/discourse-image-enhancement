# frozen_string_literal: true

DiscourseImageEnhancement::Engine.routes.draw do
  get "/image-search" => "image_enhancement#index"
  get "/image-search/search" => "image_enhancement#search"
end

Discourse::Application.routes.draw { mount ::DiscourseImageEnhancement::Engine, at: "/" }
