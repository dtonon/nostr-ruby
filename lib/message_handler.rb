module Nostr
  class MessageHandler
    def self.handle(message)

      message = JSON.parse(message) rescue ["?", message]
      type = message[0]
      strategy_class = case type
        when 'EVENT' then EventMessageStrategy
        when 'OK' then OkMessageStrategy
        when 'EOSE' then EoseMessageStrategy
        when 'CLOSED' then ClosedMessageStrategy
        when 'NOTICE' then NoticeMessageStrategy
        else UnknownMessageStrategy
      end

      processed_data = strategy_class.new(message).process
      type == "EVENT" ? processed_data : ParsedData.new(processed_data)

    end
  end

  class BaseMessageStrategy
    def initialize(message)
      @message = message
    end

    def process
      raise NotImplementedError
    end
  end

  class EventMessageStrategy < BaseMessageStrategy
    def process
      Event.from_message(@message)
    end
  end

  class OkMessageStrategy < BaseMessageStrategy
    def process
      {
        type: 'OK',
        event_id: @message[1],
        success: @message[2],
        message: @message[3]
      }
    end
  end

  class EoseMessageStrategy < BaseMessageStrategy
    def process
      {
        type: 'EOSE',
        subscription_id: @message[1]
      }
    end
  end

  class ClosedMessageStrategy < BaseMessageStrategy
    def process
      {
        type: 'CLOSED',
        subscription_id: @message[1],
        reason: @message[2]
      }
    end
  end

  class NoticeMessageStrategy < BaseMessageStrategy
    def process
      {
        type: 'NOTICE',
        message: @message[1]
      }
    end
  end

  class UnknownMessageStrategy < BaseMessageStrategy
    def process
      {
        type: 'UNKNOWN',
        raw_message: @message
      }
    end
  end
end

class ParsedData
  def initialize(data)
    @data = data
  end

  def type
    @data[:type]
  end

  def method_missing(method_name, *args, &block)
    if @data.key?(method_name)
      @data[method_name]
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @data.key?(method_name) || super
  end
end