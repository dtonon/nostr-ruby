module Nostr
  class Event
    include CryptoTools

    ATTRIBUTES = [:kind, :pubkey, :created_at, :tags, :content, :id, :sig, :pow, :delegation, :recipient]

    # Create attr_reader for each attribute name
    ATTRIBUTES.each do |attribute|
      attr_reader attribute
    end

    attr_reader :errors

    class ValidationError < StandardError; end

    def initialize(
      kind:,
      pubkey: nil,
      created_at: nil,
      tags: [],
      content: nil,
      id: nil,
      sig: nil,
      pow: nil,
      delegation: nil,
      recipient: nil,
      subscription_id: nil
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

    def type
      "EVENT"
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

    def signable?
      @errors = []

      # Check mandatory fields
      @errors << "Kind is missing" if @kind.nil?
      @errors << "Created at is missing" if @created_at.nil?

      # Type validations
      @errors << "Pubkey must be a string" if @pubkey && !@pubkey.is_a?(String)
      @errors << "Kind must be an integer" unless @kind.is_a?(Integer)
      if @created_at
        # Check if it's a valid Unix timestamp or can be converted to one
        begin
          timestamp = if @created_at.is_a?(Time)
            @created_at.to_i
          elsif @created_at.is_a?(Integer)
            @created_at
          elsif @created_at.respond_to?(:to_time)
            @created_at.to_time.to_i
          else
            raise ArgumentError
          end

          # Validate timestamp range
          @errors << "Created at is not a valid timestamp" unless
            timestamp.is_a?(Integer) &&
            timestamp >= 0
        rescue
          @errors << "Created at must be a valid datetime or Unix timestamp"
        end
      end
      @errors << "Tags must be an array" unless @tags.is_a?(Array)

      @errors << "Content must be a string" if @content && !@content.is_a?(String)
      @errors << "ID must be a string" if @id && !@id.is_a?(String)
      @errors << "Signature must be a string" if @sig && !@sig.is_a?(String)
      @errors << "POW must be an integer" if @pow && !@pow.is_a?(Integer)
      @errors << "Delegation must be an array" if @delegation && !@delegation.is_a?(Array)
      @errors << "Recipient must be a string" if @recipient && !@recipient.is_a?(String)

      if @errors.any?
        raise ValidationError, @errors.join(", ")
      end

      true
    end

    def valid?
      begin
        signable?
      rescue ValidationError => e
        return false
      end

      # Additional checks for a valid signed event
      @errors = []
      @errors << "ID is missing" if @id.nil?
      @errors << "Signature is missing" if @sig.nil?
      @errors << "Pubkey is missing" if @pubkey.nil?

      if @errors.any?
        raise ValidationError, @errors.join(", ")
      end

      true
    end

    def self.from_message(message)
      subscription_id = message[1]
      event_data = message[2]

      event = new(
        subscription_id: subscription_id,
        kind: event_data["kind"],
        pubkey: event_data["pubkey"],
        created_at: event_data["created_at"],
        tags: event_data["tags"],
        content: event_data["content"],
        id: event_data["id"],
        sig: event_data["sig"],
        pow: event_data["nonce"]&.last&.to_i
      )
      raise ArgumentError, "Event is not valid" unless event.valid?
      return event
    end

  private

    def reset!
      @id = nil
      @sign = nil
    end

  end
end