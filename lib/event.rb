module Nostr
  class Event
    include CryptoTools

    ATTRIBUTES = [:kind, :pubkey, :created_at, :tags, :content, :id, :sig, :pow, :delegation, :recipient]

    # Create attr_reader for each attribute name
    ATTRIBUTES.each do |attribute|
      attr_reader attribute
    end

    def initialize(
      kind:,
      pubkey:,
      created_at: nil,
      tags: [],
      content: nil,
      id: nil,
      sig: nil,
      pow: nil,
      delegation: nil,
      recipient: nil
    )
      @pubkey = pubkey
      @created_at = created_at ? created_at : Time.now.utc.to_i
      @kind = kind
      @tags = tags
      @content = content
      @id = id
      @sig = sig

      @pow = pow
      @delegation = delegation

      if @kind == Nostr::Kind::DIRECT_MESSAGE
        if recipient
          @recipient = recipient
          @tags << ["p", recipient]
        else
          @recipient = @tags.select{|t| t[0] == "p"}.first[1]
        end
      end
    end

    # Create setter methods for each attribute name
    ATTRIBUTES.each do |attribute|
      define_method("#{attribute}=") do |value|
        return if instance_variable_get("@#{attribute}") == value
        instance_variable_set("@#{attribute}", value)
        reset! unless attribute == :id || attribute == :sig
      end
    end

    def content=(content)
      return if @content == content
      @content = content
      reset!
    end

    def recipient=(recipient)
      return if @recipient == recipient
      @tags = @tags.delete_if { |t| t[0] == "p" && t[1] == @recipient }
      @recipient = recipient
      @tags << ["p", @recipient]
      @content = nil
      reset!
    end

    def has_tag?(tag)
      @tags.each_slice(2).any? { |e| e.first == tag }
    end

    def to_json
      {
        'kind': @kind,
        'pubkey': @pubkey,
        'created_at': @created_at,
        'tags': @tags,
        'content': @content,
        'id': @id,
        'sig': @sig,
      }
    end

    def match_pow_difficulty?
      self.match_pow_difficulty?(@id, pow)
    end

    def self.match_pow_difficulty?(event_id, pow)
      pow.nil? || pow == [event_id].pack("H*").unpack("B*")[0].index('1')
    end

    def serialize
      [
        0,
        @pubkey,
        @created_at,
        @kind,
        @tags,
        @content
      ]
    end

  private

    def reset!
      @id = nil
      @sign = nil
    end

  end
end