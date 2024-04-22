module Nostr
  class ContactList < Nostr::Event

    attr_reader :contact_list

    def initialize(
      pubkey,
      contact_list
    )
      @contact_list = contact_list
      super(
        Nostr::CONTACT_LIST_KIND,
        pubkey,
        Time.now.utc.to_i,
        @contact_list
      )
    end

    def contacts
      @tags
    end

  end
end