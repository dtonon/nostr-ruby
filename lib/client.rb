require 'faye/websocket'
require 'eventmachine'
require 'thread'

module Nostr
  class Client

    attr_reader :signer

    def initialize(signer: nil, private_key: nil, relay: nil)
      @relay = relay
      @on_open = nil
      @on_message = nil
      @on_error = nil
      @on_close = nil
      @running = false
      @expected_response_id = nil
      @response_condition = ConditionVariable.new
      @response_mutex = Mutex.new
      @event_to_publish = nil

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

    def start
      @running = true
      @thread = Thread.new do
        EM.run do
          @ws = Faye::WebSocket::Client.new(@relay)

          # Event when the connection is opened
          @ws.on :open do |event|
            puts 'WebSocket connection opened'
            @on_open.call(event) if @on_open

            # Publish the event after the connection is opened
            publish(@event_to_publish) if @event_to_publish
          end

          # Event when a new message is received
          @ws.on :message do |event|
            data = JSON.parse(event.data)

            if data[1] == @expected_response_id
              @last_response = data
              # Signal that a response has been received
              @response_mutex.synchronize do
                @response_condition.signal
              end
            end

            @on_message.call(event.data) if @on_message
          end

          # Event when an error occurs
          @ws.on :error do |event|
            @on_error.call(event.message) if @on_error
          end

          # Event when the connection is closed
          @ws.on :close do |event|
            @on_close.call(event.code, event.reason) if @on_close
            @running = false
            EM.stop
          end
        end
      end
    end

    def running?
      @running
    end

    def stop
      @running = false
      @ws.close if @ws
      @thread.join if @thread
    end

    def publish(event)
      payload = ['EVENT', event.to_json].to_json
      @ws.send(payload) if @ws
    end

    def publish_and_wait(event)
      @event_to_publish = event # Store the event to publish
      @expected_response_id = event.id # Set the expected response ID based on the event
      start unless running?

      # Wait for the response using the condition variable
      @response_mutex.synchronize do
        @response_condition.wait(@response_mutex) # Wait until signaled
      end

      @last_response
    end

  end
end