module CryptoTools

  def self.calculate_shared_key(priv_key_a, pub_key_b)
    ec = OpenSSL::PKey::EC.new('secp256k1')
    ec.private_key = OpenSSL::BN.new(priv_key_a, 16)
    pub_key_hex = "02#{pub_key_b}"
    pub_key_bn = OpenSSL::BN.new(pub_key_hex, 16)
    secret_point = OpenSSL::PKey::EC::Point.new(ec.group, pub_key_bn)
    ec.dh_compute_key(secret_point)
  end

  def self.aes_256_cbc_encrypt(priv_key_a, pub_key_b, payload)
    cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    cipher.encrypt
    cipher.iv = iv = cipher.random_iv
    cipher.key = calculate_shared_key(priv_key_a, pub_key_b)
    encrypted_text = cipher.update(payload)
    encrypted_text << cipher.final
    encrypted_text = "#{Base64.encode64(encrypted_text)}?iv=#{Base64.encode64(iv)}"
    encrypted_text.gsub("\n", '')
  end

  def self.aes_256_cbc_decrypt(priv_key_a, pub_key_b, payload, iv)
    cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    cipher.decrypt
    cipher.iv = Base64.decode64(iv)
    cipher.key = calculate_shared_key(priv_key_a, pub_key_b)
    (cipher.update(Base64.decode64(payload)) + cipher.final).force_encoding('UTF-8')
  end

end