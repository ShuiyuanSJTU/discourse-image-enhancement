module ::DiscourseImageEnhancement
  class Filter
    def self.supported_images
      @@supported_images ||= Set.new %w[jpg jpeg png webp]
    end

    def self.supported_images_regexp
      @@supported_images_regexp ||= /\.(#{supported_images.to_a.join("|")})$/i
    end

    def self.filter_post(posts)
      posts = posts.visible.public_posts.joins(topic: :category)
        .where('categories.read_restricted' => false)
      if SiteSetting.tagging_enabled && SiteSetting.image_enhancement_ignored_tags.present?
        posts = posts.where("NOT EXISTS (
          SELECT 1
          FROM topic_tags
          INNER JOIN tags ON topic_tags.tag_id = tags.id
          WHERE topic_tags.topic_id = topics.id
          AND tags.name IN (?)
        )", SiteSetting.image_enhancement_ignored_tags.split('|'))
      end
      posts
    end

    def self.filter_upload(uploads, exclude_existing: true)
      uploads = uploads.where('filesize <= ?', SiteSetting.image_enhancement_max_image_size_kb.kilobytes)
        .where('width >= ?', SiteSetting.image_enhancement_min_image_width)
        .where('height >= ?', SiteSetting.image_enhancement_min_image_height)
        .where('original_filename ~* ?', supported_images_regexp.source)
      if exclude_existing
        uploads = uploads.where('NOT EXISTS (
            SELECT 1
            FROM image_search_data
            WHERE image_search_data.sha1 = COALESCE(uploads.original_sha1, uploads.sha1)
          )')
      end
      uploads
    end

    def self.posts_need_analysis(exclude_existing: true)
      filter_post(Post).joins(:uploads)
        .merge(filter_upload(Upload, exclude_existing: exclude_existing))
    end

    def self.uploads_need_analysis(exclude_existing: true)
      filter_upload(Upload, exclude_existing: exclude_existing)
        .joins(:posts).merge(filter_post(Post))
    end

    def self.image_search_data_need_remove
      ImageSearchData.where.not(sha1:
        uploads_need_analysis(exclude_existing: false).joins("JOIN image_search_data ON image_search_data.sha1 = COALESCE(uploads.original_sha1, uploads.sha1)").select("image_search_data.sha1")
      )
    end
  end
end