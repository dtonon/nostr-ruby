require_relative 'event_wizard'
require 'faye/websocket'

module Nostr

  class Client
    include EventWizard

    attr_reader :signer
    attr_reader :relay
    attr_reader :subscriptions


    def initialize(signer: nil, private_key: nil, relay: nil, context: Context.new(timeout: 5))
      initialize_event_emitter

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

      @subscriptions = {}
      @outbound_channel = EventMachine::Channel.new
      @inbound_channel = EventMachine::Channel.new

      @inbound_channel.subscribe do |msg|
        case msg[:type]
        when :open
          emit :connect, msg[:relay]
        when :message
          parsed_data = Nostr::MessageHandler.handle(msg[:data])
          emit :message, parsed_data
          emit :event, parsed_data if parsed_data.type == "EVENT"
          emit :ok, parsed_data if parsed_data.type == "OK"
          emit :eose, parsed_data if parsed_data.type == "EOSE"
          emit :closed, parsed_data if parsed_data.type == "CLOSED"
          emit :notice, parsed_data if parsed_data.type == "NOTICE"
        when :error
          emit :error, msg[:message]
        when :close
          emit :close, msg[:code], msg[:reason]
        end
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
      @thread = Thread.new do
        EM.run do
          @ws_client = Faye::WebSocket::Client.new(@relay)

          @outbound_channel.subscribe { |msg| @ws_client.send(msg) && emit(:send, msg) }

          @ws_client.on :open do
            @running = true
            @inbound_channel.push(type: :open, relay: @relay)
          end

          @ws_client.on :message do |event|
            @inbound_channel.push(type: :message, data: event.data)
          end

          @ws_client.on :error do |event|
            @inbound_channel.push(type: :error, message: event.message)
          end

          @ws_client.on :close do |event|
            context.cancel
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
      EM.next_tick do
        @ws_client.close if @ws_client
        EM.add_timer(0.1) do
          EM.stop if EM.reactor_running?
        end
      end
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
        context.wait do
          @response_mutex.synchronize do
            @response_condition.wait(@response_mutex) # Wait for a response
          end
        end
      end

      @inbound_channel.subscribe do |message|
        parsed_data = Nostr::MessageHandler.handle(message[:data])
        if parsed_data.type == "OK" && parsed_data.event_id == event.id
          response = parsed_data
          @response_condition.signal
        end
      end

      response_thread.join
      close if close_on_finish

      response
    end

    def subscribe(subscription_id: SecureRandom.hex, filter: Filter.new)
      @subscriptions[subscription_id] = filter
      @outbound_channel.push(["REQ", subscription_id, filter.to_h].to_json)
      @subscriptions[subscription_id]
      subscription_id
    end

    def unsubscribe(subscription_id)
      @subscriptions.delete(subscription_id)
      @outbound_channel.push(["CLOSE", subscription_id].to_json)
    end

    def unsubscribe_all
      @subscriptions.each{|s| unsubscribe(s[0])}
    end

  end
end