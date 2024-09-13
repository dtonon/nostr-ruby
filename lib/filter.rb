module Nostr
  class Filter

    attr_reader :id
    attr_reader :kinds
    attr_reader :authors
    attr_reader :tags
    attr_reader :since
    attr_reader :until
    attr_reader :limit
    attr_reader :search
    ('a'..'z').each { |char| attr_reader char.to_sym }
    ('A'..'Z').each { |char| attr_reader char.to_sym }

    def initialize(ids: nil, kinds: nil, authors: nil, since: nil, limit: nil, search: nil, **params)
      @id = id
      @kinds = kinds
      @authors = authors
      @tags = tags
      @since = since.nil? ? nil : since.to_i
      @limit = limit
      @search = search
      @until = params[:until].nil? ? nil : params[:until].to_i # this is an hack to permit the use of the 'until' param, since it is a reserved word

      # Handle additional parameters with a-zA-Z names
      params.each do |key, value|
        if key.to_s.match?(/\A[a-zA-Z]\z/)
          instance_variable_set("@#{key}", value)
        end
      end
    end

    def to_h
      result = {
        id: @id,
        authors: @authors,
        kinds: @kinds,
        since: @since,
        until: @until,
        limit: @limit,
        search: @search
      }.compact

      ('a'..'z').each do |char|
        var_value = instance_variable_get("@#{char}")
        result["##{char}"] = var_value unless var_value.nil?
      end
      ('A'..'Z').each do |char|
        var_value = instance_variable_get("@#{char}")
        result["##{char}"] = var_value unless var_value.nil?
      end

      result
    end

  end
end
