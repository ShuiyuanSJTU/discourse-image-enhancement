# frozen_string_literal: true

class DiscourseImageEnhancement::ImageSearch
  class AdvancedFilter
    def filter_post(posts)
      self.class.filter_post(posts)
    end

    def self.filter_post(posts)
      Filter.filter_post(posts)
    end

    def self.advanced_filter(trigger, &block)
      advanced_filters[trigger] = block
    end

    def self.advanced_filters
      @advanced_filters ||= {}
    end

    def process_advanced_search!(term)
      term
        .to_s
        .scan(/(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/)
        .to_a
        .map do |(word, _)|
          next if word.blank?

          found = false

          self.class.advanced_filters.each do |matcher, block|
            cleaned = word.gsub(/["']/, "")
            if cleaned =~ matcher
              (@filters ||= []) << [block, $1]
              found = true
            end
          end

          found ? nil : word
        end
        .compact
        .join(" ")
    end

    def apply_advanced_filters(posts)
      @filters.each do |block, match|
        if block.arity == 1
          posts = instance_exec(posts, &block) || posts
        else
          posts = instance_exec(posts, match, &block) || posts
        end
      end if @filters
      posts
    end

    advanced_filter(/\Atopic:(\d+)\z/i) { |posts, match| posts.where(topic_id: match.to_i) }

    advanced_filter(/\Abefore:(.*)\z/i) do |posts, match|
      if date = Search.word_to_date(match)
        posts.where("posts.created_at < ?", date)
      else
        posts
      end
    end

    advanced_filter(/\Aafter:(.*)\z/i) do |posts, match|
      if date = Search.word_to_date(match)
        posts.where("posts.created_at > ?", date)
      else
        posts
      end
    end

    advanced_filter(/\A\@(\S+)\z/i) do |posts, match|
      username = User.normalize_username(match)

      user_id = User.not_staged.where(username_lower: username).pick(:id)

      user_id = @guardian.user&.id if !user_id && username == "me"

      if user_id
        posts.where("posts.user_id = ?", user_id)
      else
        posts.none
      end
    end

    advanced_filter(/\Atags:(\S+)\z/i) do |posts, match|
      tag_names = match.split(",")
      tags = Tag.where(name: tag_names)
      posts.where(id: Post.joins({ topic: :tags }).where(tags: { id: tags }))
    end

    advanced_filter(/\A\#([\p{L}\p{M}0-9\-:=]+)\z/i) do |posts, match|
      category_slug, subcategory_slug = match.to_s.split(":")
      next unless category_slug

      exact = true
      if category_slug[0] == "="
        category_slug = category_slug[1..-1]
      else
        exact = false
      end

      category_id =
        if subcategory_slug
          Category
            .where("lower(slug) = ?", subcategory_slug.downcase)
            .where(
              parent_category_id:
                Category.where("lower(slug) = ?", category_slug.downcase).select(:id),
            )
            .pick(:id)
        else
          Category
            .where("lower(slug) = ?", category_slug.downcase)
            .order("case when parent_category_id is null then 0 else 1 end")
            .pick(:id)
        end

      if category_id
        category_ids = [category_id]
        category_ids += Category.subcategory_ids(category_id) if !exact

        posts.joins(:topic).where({ topics: { category_id: category_ids } })
      else
        posts.none
      end
    end
  end
end