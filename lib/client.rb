module Nostr
  class Client

    attr_reader :signer

    def initialize(signer: nil, private_key: nil)
      if signer
        @signer = signer
      elsif private_key
        @signer = Nostr::Signer.new(private_key: private_key)
      end
    end

    def nsec
      signer.nsec
    end

    def private_key
      signer.private_key
    end

    def npub
      signer.npub
    end

    def public_key
      signer.public_key
    end

    def sign(event)
      signer.sign(event)
    end

    def decrypt(event)
      signer.decrypt(event)
    end

    def generate_delegation_tag(to:, conditions:)
      signer.generate_delegation_tag(to, conditions)
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