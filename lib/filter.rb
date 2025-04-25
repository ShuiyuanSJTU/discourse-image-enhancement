# frozen_string_literal: true
module ::DiscourseImageEnhancement
  class Filter
    def self.supported_images
      @@supported_images ||= Set.new %w[jpg jpeg png webp]
    end

    def self.supported_images_regexp
      @@supported_images_regexp ||= /\.(#{supported_images.to_a.join("|")})$/i
    end

    def self.filter_post(posts)
      # Filter the posts that need to be analyzed
      # It does not check the number of images in the posts
      posts =
        posts
          .visible
          .public_posts
          .joins(topic: :category)
          .where(categories: { read_restricted: false })
      if SiteSetting.image_enhancement_ignored_categories.present?
        posts =
          posts.where(
            "categories.id NOT IN (?)",
            SiteSetting.image_enhancement_ignored_categories.split("|").map(&:to_i),
          )
      end
      if SiteSetting.tagging_enabled && SiteSetting.image_enhancement_ignored_tags.present?
        posts =
          posts.where(
            "NOT EXISTS (
          SELECT 1
          FROM topic_tags
          INNER JOIN tags ON topic_tags.tag_id = tags.id
          WHERE topic_tags.topic_id = topics.id
          AND tags.name IN (?)
        )",
            SiteSetting.image_enhancement_ignored_tags.split("|"),
          )
      end
      posts
    end

    def self.filter_upload(
      uploads,
      exclude_existing: true,
      include_partially_analyzed: false,
      max_retry_times: nil
    )
      # Filter the uploads that need to be analyzed
      # It does not check which posts the uploads belong to
      max_retry_times =
        SiteSetting.image_enhancement_max_retry_times_per_image if max_retry_times.nil?
      uploads =
        uploads
          .where("filesize <= ?", SiteSetting.image_enhancement_max_image_size_kb.kilobytes)
          .where("width >= ?", SiteSetting.image_enhancement_min_image_width)
          .where("height >= ?", SiteSetting.image_enhancement_min_image_height)
          .where("original_filename ~* ?", supported_images_regexp.source)
      if exclude_existing
        if include_partially_analyzed
          # Only exclude the images that have been fully analyzed
          # useful when backfilling
          uploads =
            uploads.left_outer_joins(:image_search_data).where(
              "image_search_data.upload_id IS NULL
                OR image_search_data.ocr_text_search_data IS NULL
                OR image_search_data.embeddings IS NULL",
            )
        else
          uploads =
            uploads.left_outer_joins(:image_search_data).where(
              "image_search_data.upload_id IS NULL
                OR (
                  image_search_data.ocr_text_search_data IS NULL
                  AND image_search_data.embeddings IS NULL
                )",
            )
        end
      end
      if max_retry_times > 0
        # We need to exclude the images reached max retry times
        uploads =
          uploads.left_outer_joins(:image_search_data).where(
            "retry_times is NULL OR retry_times < ?",
            max_retry_times,
          )
      end
      uploads = uploads.where.not(id: CustomEmoji.pluck(:upload_id))
      uploads
    end

    def self.posts_need_analysis(
      exclude_existing: true,
      max_images_per_post: SiteSetting.image_enhancement_max_images_per_post
    )
      posts =
        filter_post(Post).joins(:uploads).where(
          uploads: {
            id: filter_upload(Upload, exclude_existing: exclude_existing),
          },
        )
      if max_images_per_post.present? && max_images_per_post > 0
        posts =
          posts
            .group("posts.id")
            .having("COUNT(uploads.id) <= ? AND COUNT(uploads.id) > 0", max_images_per_post)
            .select("posts.*")
      end
      posts
    end

    def self.uploads_need_analysis(
      exclude_existing: true,
      max_retry_times: nil,
      include_missing_ocr: nil,
      include_missing_embeddings: nil
    )
      max_retry_times =
        SiteSetting.image_enhancement_max_retry_times_per_image if max_retry_times.nil?
      include_missing_ocr =
        SiteSetting.image_enhancement_analyze_ocr_enabled if include_missing_ocr.nil?
      include_missing_embeddings =
        SiteSetting.image_enhancement_analyze_embedding_enabled if include_missing_embeddings.nil?
      uploads =
        filter_upload(
          Upload,
          exclude_existing: exclude_existing,
          include_partially_analyzed: true,
          max_retry_times: max_retry_times,
        ).joins(:posts).where(posts: { id: filter_post(Post) })
      if exclude_existing
        # If neither ocr nor embedding is enabled, we don't need to analyze the image
        conditions = ["0=1"] # default false
        conditions << "image_search_data.ocr_text_search_data IS NULL" if include_missing_ocr
        conditions << "image_search_data.embeddings IS NULL" if include_missing_embeddings
        uploads = uploads.left_outer_joins(:image_search_data).where(conditions.join(" OR "))
      end
      uploads
    end

    def self.image_search_data_need_remove
      ImageSearchData.where.not(
        upload_id: uploads_need_analysis(exclude_existing: false, max_retry_times: -1),
      )
    end
  end
end
