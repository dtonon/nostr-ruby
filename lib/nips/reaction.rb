module Nostr
  class Reaction < Nostr::Event

    attr_reader :reaction
    attr_reader :event

    def initialize(
      pubkey,
      event,
      author = nil,
      reaction = "+"
    )
      @reaction = reaction
      @event = event
      @author = author
      tags = []
      tags << ['e', event]
      tags << ['p', author]
      super(
        Nostr::REACTION_KIND,
        pubkey,
        Time.now.utc.to_i,
        tags,
        @reaction
      )
    end

  end
end