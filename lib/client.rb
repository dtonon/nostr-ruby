require 'faye/websocket'
require 'eventmachine'

module Nostr
  class Client

    attr_reader :signer

    def initialize(signer: nil, private_key: nil, relay: nil)
      @relay = relay
      @on_open = nil
      @on_message = nil
      @on_error = nil
      @on_close = nil

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

    def on_open(&block)
      @on_open = block
    end

    def on_message(&block)
      @on_message = block
    end

    def on_error(&block)
      @on_error = block
    end

    def on_close(&block)
      @on_close = block
    end

    def run
      EM.run do
        @ws = Faye::WebSocket::Client.new(@relay)

        # Event when the connection is opened
        @ws.on :open do |event|
          @on_open.call(event) if @on_open
        end

        # Event when a new message is received
        @ws.on :message do |event|
          @on_message.call(event.data) if @on_message
        end

        # Event when an error occurs
        @ws.on :error do |event|
          @on_error.call(event.message) if @on_error
        end

        # Event when the connection is closed
        @ws.on :close do |event|
          @on_close.call(event.code, event.reason) if @on_close
          EM.stop # Stop the EventMachine loop
        end
      end
    end

    def stop
      @ws.close if @ws
    end

    def publish(event)
      payload = ['EVENT', event.to_json].to_json
      @ws.send(payload) if @ws
    end

  end
end