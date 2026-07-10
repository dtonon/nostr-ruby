require 'bech32'
require 'bech32/nostr'
require 'bech32/nostr/entity'

module Nostr
  class Bech32

    def self.decode(bech32_entity)
      e = ::Bech32::Nostr::NIP19.decode(bech32_entity)

      case e
      in ::Bech32::Nostr::BareEntity
        { hrp: e.hrp, data: e.data }
      in ::Bech32::Nostr::TLVEntity
        { hrp: e.hrp, data: transform_entries(e.entries) }
      end
    end

    def self.encode(hrp, data)
      ::Bech32::Nostr::BareEntity.new(hrp, data).encode
    end

    def self.encode_npub(data)
      encode("npub", data)
    end

    def self.encode_nsec(data)
      encode("nsec", data)
    end

    def self.encode_nprofile(pubkey:, relays: [])
      entry_relays = relays.map do |relay_url|
        ::Bech32::Nostr::TLVEntry.new(::Bech32::Nostr::TLVEntity::TYPE_RELAY, relay_url)
      end

      pubkey_entry = ::Bech32::Nostr::TLVEntry.new(::Bech32::Nostr::TLVEntity::TYPE_SPECIAL, pubkey)
      entries = [pubkey_entry, *entry_relays].compact
      ::Bech32::Nostr::TLVEntity.new(::Bech32::Nostr::NIP19::HRP_PROFILE, entries).encode
    end

    def self.encode_note(data)
      encode("note", data)
    end

    def self.encode_nevent(id:, relays: [], kind: nil)
      entry_relays = relays.map do |r|
        ::Bech32::Nostr::TLVEntry.new(::Bech32::Nostr::TLVEntity::TYPE_RELAY, r)
      end

      entry_id = ::Bech32::Nostr::TLVEntry.new(::Bech32::Nostr::TLVEntity::TYPE_SPECIAL, id)
      entry_kind = kind ? ::Bech32::Nostr::TLVEntry.new(::Bech32::Nostr::TLVEntity::TYPE_KIND, kind) : nil

      entries = [entry_id, *entry_relays, entry_kind].compact
      ::Bech32::Nostr::TLVEntity.new(::Bech32::Nostr::NIP19::HRP_EVENT, entries).encode
    end

    def self.encode_naddr(author:, relays: [], kind: nil, identifier: nil)
      entry_relays = relays.map do |r|
        ::Bech32::Nostr::TLVEntry.new(::Bech32::Nostr::TLVEntity::TYPE_RELAY, r)
      end

      entry_author = ::Bech32::Nostr::TLVEntry.new(::Bech32::Nostr::TLVEntity::TYPE_AUTHOR, author)
      entry_kind = ::Bech32::Nostr::TLVEntry.new(::Bech32::Nostr::TLVEntity::TYPE_KIND, kind)
      entry_identifier = ::Bech32::Nostr::TLVEntry.new(::Bech32::Nostr::TLVEntity::TYPE_SPECIAL, identifier)

      entries = [entry_author, *entry_relays, entry_kind, entry_identifier].compact
      ::Bech32::Nostr::TLVEntity.new(::Bech32::Nostr::NIP19::HRP_EVENT_COORDINATE, entries).encode
    end

  private

    # Helper method to transform entries into a hash
    def self.transform_entries(entries)
      entries.each_with_object({}) do |entry, hash|
        label = entry.instance_variable_get(:@label).to_sym
        value = entry.instance_variable_get(:@value)

        hash[label] ||= []
        hash[label] << value
      end
    end

  end
end
