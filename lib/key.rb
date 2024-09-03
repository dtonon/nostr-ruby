module Nostr
  class Key

    def self.generate_private_key
      group = ECDSA::Group::Secp256k1
      (1 + SecureRandom.random_number(group.order - 1)).to_s(16).rjust(64, '0')
    end

    def self.get_public_key(private_key)
      group = ECDSA::Group::Secp256k1
      group.generator.multiply_by_scalar(private_key.to_i(16)).x.to_s(16).rjust(64, '0')
    end

    def self.decode(bech32_key)
      public_addr = CustomAddr.new(bech32_key)
      public_addr.to_scriptpubkey
    end

    def self.encode_private_key(private_key)
      Nostr::Key::to_bech32(private_key, 'nsec')
    end

    def self.encode_public_key(public_key)
      Nostr::Key::to_bech32(public_key, 'npub')
    end

  private

    def self.to_bech32(hex_key, hrp)
      custom_addr = CustomAddr.new
      custom_addr.scriptpubkey = hex_key
      custom_addr.hrp = hrp
      custom_addr.addr
    end

  end
end