module Nostr
  class Metadata < Nostr::Event

    attr_reader :metadata

    def initialize(
      pubkey,
      metadata = {}
    )
      @metadata = metadata
      super(
        Nostr::METADATA_KIND,
        pubkey,
        Time.now.utc.to_i,
        [],
        metadata.to_json
      )
    end

    def metadata
      @metadata.slice(
        :name, :display_name, :about, :picture,
        :banner, :nip05, :lud16, :website
      )
    end

  end
end