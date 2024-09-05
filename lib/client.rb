module Nostr
  class Client

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
      event.send("sign", private_key)
    end

    def decrypt(event)
      event.send("decrypt", private_key)
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

    def send(event, relay)
      response = nil
      ws = WebSocket::Client::Simple.connect relay
      ws.on :message do |msg|
        puts msg
        response = JSON.parse(msg.data)
        ws.close
      end
      ws.on :open do
        payload = ['EVENT', event.to_json]
        puts payload.inspect
        ws.send payload.to_json
      end
      while response.nil? do
        sleep 0.1
      end
      response[0] == 'OK'
    end

  end
end