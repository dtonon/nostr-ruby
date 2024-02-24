require_relative 'base_event'

module NostrRuby
  module Nips
    # Metadata event (NIP-01 / NIP-24)
    #
    # @see https://github.com/nostr-protocol/nips/blob/master/01.md
    # @see https://github.com/nostr-protocol/nips/blob/master/24.md
    class MetadataEvent < BaseEvent
      METADATA_KIND = 0

      # @param metadata [Hash] list of nostr account metadata
      # @option metadata [String] :name the "@" account name
      # @option metadata [String] :display_name the friendly displayed name
      # @option metadata [String] :about the profile description
      # @option metadata [String] :picture the profile picture
      # @option metadata [String] :banner the profile banner
      # @option metadata [String] :nip05 the NIP-05 verification address
      # @option metadata [String] :lud16 the lightning network address
      # @option metadata [String] :website account website URL
      def initialize(metadata = {})
        super()

        @metadata = metadata
      end

      def call
        validate!

        {
          kind: METADATA_KIND,
          tags: [],
          content: metadata.to_json,
          created_at: now
        }
      end

      private

      def validate!
      end

      def metadata
        @metadata.slice(
          :name, :display_name, :about, :picture,
          :banner, :nip05, :lud16, :website
        )
      end
    end
  end
end
