module Nostr
  class Event
    include CryptoTools

    attr_reader :kind
    attr_reader :pubkey
    attr_reader :created_at
    attr_reader :tags
    attr_reader :content
    attr_reader :id
    attr_reader :sig

    attr_reader :pow
    attr_reader :delegation
    attr_reader :nip4_recipient # Deprecated, kept for retrocompatibility
    attr_reader :encrypted_content

    def initialize(
      kind,
      pubkey,
      created_at,
      tags = [],
      content = nil,
      options = {}
    )
      @pubkey = pubkey
      @created_at = created_at
      @kind = kind
      @tags = tags
      @content = content
      @id = id
      @sig = sig

      # Optional
      @pow = options[:pow] if options[:pow]
      @delegation = options[:delegation] if options[:delegation]
      @nip4_recipient = options[:nip4_recipient] if options[:nip4_recipient]
    end

    def generate_delegation(delegatee_pubkey, conditions, private_key)
      delegation_message_sha256 = Digest::SHA256.hexdigest("nostr:delegation:#{delegatee_pubkey}:#{conditions}")
      delegation_sig = Schnorr.sign(Array(delegation_message_sha256).pack('H*'), Array(private_key).pack('H*')).encode.unpack('H*')[0]
      delegation_tag = [
        "delegation",
        @public_key,
        conditions,
        delegation_sig
      ]
      delegation_tag
    end

    def set_delegation(delegatee_pubkey, conditions, private_key)
      delegation_tag = generate_delegation(delegatee_pubkey, conditions, private_key)
      @tags << delegation_tag
      reset!
    end

    def has_tag?(tag)
      @tags.each_slice(2).any? { |e| e.first == tag }
    end

    def match_pow_difficulty?
      self.match_pow_difficulty?(@id, pow)
    end

    def self.match_pow_difficulty?(event_id, pow)
      pow.nil? || pow == [event_id].pack("H*").unpack("B*")[0].index('1')
    end

  private

    def serialize
      [
        0,
        @pubkey,
        @created_at,
        @kind,
        @tags,
        @encrypted_content || @content
      ]
    end

    def sign(private_key)

      # TODO Validate if the npub is correctly derivable from the private_key

      if @nip4_recipient
        @encrypted_content = CryptoTools.aes_256_cbc_encrypt(private_key, @nip4_recipient, @content)
      end

      if @delegation && !has_tag?("delegation")
        set_delegation(@delegation[:delegatee_pubkey], @delegation[:conditions], private_key)
      end

      event_sha256_digest = nil
      if @pow
        nonce = 1
        loop do
          nonce_tag = ['nonce', nonce.to_s, @pow.to_s]
          nonced_serialized_event = self.serialize.clone
          nonced_serialized_event[4] = nonced_serialized_event[4] + [nonce_tag]
          event_sha256_digest = Digest::SHA256.hexdigest(JSON.dump(nonced_serialized_event))
          if Nostr::Event.match_pow_difficulty?(event_sha256_digest, @pow)
            @tags << nonce_tag
            break
          end
          nonce += 1
        end
      else
        event_sha256_digest = Digest::SHA256.hexdigest(JSON.dump(self.serialize))
      end

      @id = event_sha256_digest
      private_key = Array(private_key).pack('H*')
      message = Array(@id).pack('H*')
      @sig = Schnorr.sign(message, private_key).encode.unpack('H*')[0]
      self
    end

    def reset!
      @id = nil
      @sign = nil
    end

  end
end