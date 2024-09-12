require 'event_emitter'
require 'faye/websocket'

module Nostr
  class Client
    include EventEmitter

    attr_reader :signer

    def initialize(signer: nil, private_key: nil, relay: nil, context: Context.new(timeout: 5))
      if signer
        @signer = signer
      elsif private_key
        @signer = Nostr::Signer.new(private_key: private_key)
      end

      @relay = relay
      @context = context

      @running = false
      @expected_response_id = nil
      @response_condition = ConditionVariable.new
      @response_mutex = Mutex.new
      @event_to_publish = nil

      @outbound_channel = EventMachine::Channel.new
      @inbound_channel = EventMachine::Channel.new

      @inbound_channel.subscribe do |msg|
        emit :connect, msg[:relay]              if msg[:type] == :open
        emit :message, msg[:data]               if msg[:type] == :message
        emit :error,   msg[:message]            if msg[:type] == :error
        emit :close,   msg[:code], msg[:reason] if msg[:type] == :close
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

    def connect(context: @context)
      @running = true
      @thread = Thread.new do
        EM.run do
          @ws_client = Faye::WebSocket::Client.new(@relay)

          @outbound_channel.subscribe { |msg| @ws_client.send(msg) && emit(:send, msg) }

          @ws_client.on :open do
            @inbound_channel.push(type: :open, relay: @relay)
          end

          @ws_client.on :message do |event|
            @inbound_channel.push(type: :message, data: event.data)
          end

          @ws_client.on :error do |event|
            @inbound_channel.push(type: :error, message: event.message)
          end

          @ws_client.on :close do |event|
            @inbound_channel.push(type: :close, code: event.code, reason: event.reason)
          end

        end
      end

      # Wait for the connection to be established or for the context to be canceled
      if context
        context.wait { @running }
      end

    end

    def running?
      @running
    end

    def close
      @running = false
      @ws_client.close if @ws_client
      EventMachine.stop if EventMachine.reactor_running?
      @thread.join if @thread
    end

    def publish(event)
      return false unless running?
      @outbound_channel.push(['EVENT', event.to_json].to_json)
      return true
    end

    def publish_and_wait(event, context: @context, close_on_finish: false)
      return false unless running?

      response = nil
      @outbound_channel.push(['EVENT', event.to_json].to_json)

      response_thread = Thread.new do
        @response_mutex.synchronize do
          @response_condition.wait(@response_mutex) # Wait for a response
        end
      end

      @inbound_channel.subscribe do |message|
        if message[:type] == :message && message[:data]
          data = JSON.parse(message[:data])
          if data[1] == event.id
            response = data
            @response_condition.signal
          end
        end
      end

      response_thread.join
      stop if close_on_finish

      response
    end

  end
end