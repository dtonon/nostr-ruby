module Nostr
  class ShortNote < Nostr::Event

    def initialize(
      pubkey,
      content,
      tags = {},
      options = {}
    )
      super(
        Nostr::SHORT_NOTE_KIND,
        pubkey,
        Time.now.utc.to_i,
        tags,
        content,
        options
      )
    end

  end
end