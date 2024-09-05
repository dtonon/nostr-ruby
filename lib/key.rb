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

  end
end