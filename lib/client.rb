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
      Nostr::Key.encode_private_key(@private_key)
    end

    def npub
      Nostr::Key.encode_public_key(@public_key)
    end

    def sign(event)
      event.send("sign", private_key)
    end

    def decrypt(event)
      event.send("decrypt", private_key)
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