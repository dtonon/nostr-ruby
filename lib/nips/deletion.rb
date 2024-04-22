module Nostr
  class Deletion < Nostr::Event

    attr_reader :event

    def initialize(
      pubkey,
      event
    )
      @event = event
      tags = [["e", @event]]
      super(
        Nostr::DELETION_KIND,
        pubkey,
        Time.now.utc.to_i,
        tags
      )
    end

  end
end