module Nostr
  class Bech32

    def self.decode(bech32_entity)
      e = ::Bech32::Nostr::NIP19.decode(bech32_entity)
      { hrp: e.hrp, data: e.data }
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

  end
end
