module Nostr
  class Client

    attr_reader :public_key

    def initialize(
      private_key:
    )
      @private_key = private_key

      unless @public_key
        group = ECDSA::Group::Secp256k1
        @public_key = group.generator.multiply_by_scalar(@private_key.to_i(16)).x.to_s(16).rjust(64, '0')
      end
    end

    def bech32_public_key
      bech32_keys = {}
      Nostr::Client.to_bech32(@public_key, 'npub')
    end

    def self.to_hex(bech32_key)
      public_addr = CustomAddr.new(bech32_key)
      public_addr.to_scriptpubkey
    end

    def self.to_bech32(hex_key, hrp)
      custom_addr = CustomAddr.new
      custom_addr.scriptpubkey = hex_key
      custom_addr.hrp = hrp
      custom_addr.addr
    end

    def sign(event)
      event.send("sign", private_key)
    end

    def decrypt(event)
      event.send("decrypt", private_key)
    end

  private

    attr_reader :private_key

  end
end