module Nostr
  class Signer

    attr_reader :private_key
    attr_reader :public_key

    def initialize(private_key:)
      @private_key = private_key
      unless @public_key
        @public_key = Nostr::Key::get_public_key(@private_key)
      end
    end

    def nsec
      Nostr::Bech32.encode_nsec(@private_key)
    end

    def npub
      Nostr::Bech32.encode_npub(@public_key)
    end

    def sign(event)

      raise ArgumentError, "Event is not signable" unless event.signable?

      event.pubkey = @public_key if event.pubkey.nil? || event.pubkey.empty?

      raise ArgumentError, "Pubkey doesn't match the private key" unless event.pubkey == @public_key

      if event.kind == Nostr::Kind::DIRECT_MESSAGE
        dm_recipient = event.tags.select{|t| t[0] == "p"}.first[1]
        event.content = CryptoTools.aes_256_cbc_encrypt(@private_key, dm_recipient, event.content)
      end

      if event.delegation
        event.tags << event.delegation
      end

      event_sha256_digest = nil
      if event.pow
        nonce = 1
        loop do
          nonce_tag = ['nonce', nonce.to_s, event.pow.to_s]
          nonced_serialized_event = event.serialize.clone
          nonced_serialized_event[4] = nonced_serialized_event[4] + [nonce_tag]
          event_sha256_digest = Digest::SHA256.hexdigest(JSON.dump(nonced_serialized_event))
          if Nostr::Event.match_pow_difficulty?(event_sha256_digest, event.pow)
            event.tags << nonce_tag
            break
          end
          nonce += 1
        end
      else
        event_sha256_digest = Digest::SHA256.hexdigest(JSON.dump(event.serialize))
      end

      event.id = event_sha256_digest
      binary_private_key = Array(@private_key).pack('H*')
      binary_message = Array(event.id).pack('H*')
      event.sig = Schnorr.sign(binary_message, binary_private_key).encode.unpack('H*')[0]
      event
    end

    def decrypt(event)
      case event.kind
      when Nostr::Kind::DIRECT_MESSAGE
        data = event.content.split('?iv=')[0]
        iv = event.content.split('?iv=')[1]
        dm_recipient = event.tags.select{|t| t[0] == "p"}.first[1]
        event.content = CryptoTools.aes_256_cbc_decrypt(@private_key, dm_recipient, data, iv)
        event
      else
        raise "Unable to decrypt a kind #{event.kind} event"
      end
    end

    def generate_delegation_tag(to:, conditions:)
      delegation_message_sha256 = Digest::SHA256.hexdigest("nostr:delegation:#{to}:#{conditions}")
      signature = Schnorr.sign(Array(delegation_message_sha256).pack('H*'), Array(@private_key).pack('H*')).encode.unpack('H*')[0]
      [
        "delegation",
        @public_key,
        conditions,
        signature
      ]
    end

  end
end