module NostrRuby
  module Nips
    class BaseEvent
      private

      def now
        Time.now.utc.to_i
      end
    end
  end
end
