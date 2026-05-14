module CryptoTools
  class << self
    # NIP-04, deprecated in favor of NIP-17
    def nip04_encrypt(private_key, public_key, plaintext)
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.encrypt
      cipher.iv = iv = cipher.random_iv
      cipher.key = nip04_shared_key(private_key, public_key)
      encrypted = cipher.update(plaintext) + cipher.final
      "#{Base64.strict_encode64(encrypted)}?iv=#{Base64.strict_encode64(iv)}"
    end

    def nip04_decrypt(private_key, public_key, payload)
      data, iv = payload.split('?iv=')
      raise ArgumentError, "Invalid NIP-04 payload" unless data && iv
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.decrypt
      cipher.iv = Base64.decode64(iv)
      cipher.key = nip04_shared_key(private_key, public_key)
      (cipher.update(Base64.decode64(data)) + cipher.final).force_encoding('UTF-8')
    end

    private

    def nip04_shared_key(private_key, public_key)
      ec = OpenSSL::PKey::EC.new('secp256k1')
      ec.private_key = OpenSSL::BN.new(private_key, 16)
      pub_key_bn = OpenSSL::BN.new("02#{public_key}", 16)
      secret_point = OpenSSL::PKey::EC::Point.new(ec.group, pub_key_bn)
      ec.dh_compute_key(secret_point)
    end
  end
end
