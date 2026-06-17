module CryptoTools
  class Error < StandardError; end

  NIP44_VERSION = 2
  NIP44_SALT = 'nip44-v2'.freeze
  NIP44_MIN_PLAINTEXT_SIZE = 1
  NIP44_MAX_PLAINTEXT_SIZE = 65535
  # version (1) + nonce (32) + min padded (34) + mac (32)
  NIP44_MIN_PAYLOAD_SIZE = 99
  NIP44_MAX_PAYLOAD_SIZE = 65603

  class << self
    # NIP-44 v2 (https://github.com/nostr-protocol/nips/blob/master/44.md)
    # All keys and nonces are raw binary strings, payloads are base64
    def nip44_conversation_key(private_key, public_key)
      shared_x = secp256k1_ecdh(private_key, public_key)
      OpenSSL::HMAC.digest('SHA256', NIP44_SALT, shared_x)
    end

    # The nonce parameter is exposed only for testing against the
    # official vectors, never pass it in real usage
    def nip44_encrypt(conversation_key, plaintext, nonce: nil)
      nonce ||= SecureRandom.bytes(32)
      chacha_key, chacha_nonce, hmac_key = nip44_message_keys(conversation_key, nonce)
      ciphertext = chacha20(chacha_key, chacha_nonce, nip44_pad(plaintext))
      mac = hmac_aad(hmac_key, ciphertext, nonce)
      Base64.strict_encode64([NIP44_VERSION].pack('C') + nonce + ciphertext + mac)
    end

    def nip44_decrypt(conversation_key, payload)
      raise Error, "Unsupported payload format" if payload.start_with?('#')
      begin
        data = Base64.strict_decode64(payload)
      rescue ArgumentError
        raise Error, "Invalid base64 payload"
      end
      raise Error, "Invalid payload size" unless data.bytesize.between?(NIP44_MIN_PAYLOAD_SIZE, NIP44_MAX_PAYLOAD_SIZE)

      version = data.byteslice(0).unpack1('C')
      raise Error, "Unsupported version #{version}" unless version == NIP44_VERSION

      nonce = data.byteslice(1, 32)
      ciphertext = data.byteslice(33, data.bytesize - 65)
      mac = data.byteslice(-32, 32)

      chacha_key, chacha_nonce, hmac_key = nip44_message_keys(conversation_key, nonce)
      raise Error, "Invalid MAC" unless secure_compare(hmac_aad(hmac_key, ciphertext, nonce), mac)

      nip44_unpad(chacha20(chacha_key, chacha_nonce, ciphertext))
    end

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

    def secp256k1_ecdh(private_key, public_key)
      group = ECDSA::Group::Secp256k1
      point = ECDSA::Format::PointOctetString.decode(["02#{public_key}"].pack('H*'), group)
      shared_point = point.multiply_by_scalar(private_key.to_i(16))
      # Only the x coordinate is used, per NIP-44 (unhashed ECDH output)
      ECDSA::Format::IntegerOctetString.encode(shared_point.x, 32)
    end

    def nip44_message_keys(conversation_key, nonce)
      raise Error, "Invalid conversation key length" unless conversation_key.bytesize == 32
      raise Error, "Invalid nonce length" unless nonce.bytesize == 32

      keys = hkdf_expand(conversation_key, nonce, 76)
      [keys.byteslice(0, 32), keys.byteslice(32, 12), keys.byteslice(44, 32)]
    end

    def hkdf_expand(prk, info, length)
      output = +''
      block = ''
      counter = 1
      while output.bytesize < length
        block = OpenSSL::HMAC.digest('SHA256', prk, block + info + [counter].pack('C'))
        output << block
        counter += 1
      end
      output.byteslice(0, length)
    end

    def nip44_pad(plaintext)
      unpadded = plaintext.encode('UTF-8').b
      length = unpadded.bytesize
      unless length.between?(NIP44_MIN_PLAINTEXT_SIZE, NIP44_MAX_PLAINTEXT_SIZE)
        raise Error, "Invalid plaintext length"
      end
      [length].pack('n') + unpadded + "\x00".b * (nip44_padded_length(length) - length)
    end

    def nip44_unpad(padded)
      length = padded.byteslice(0, 2)&.unpack1('n').to_i
      unpadded = padded.byteslice(2, length)
      valid = length >= NIP44_MIN_PLAINTEXT_SIZE &&
        unpadded&.bytesize == length &&
        padded.bytesize == 2 + nip44_padded_length(length)
      raise Error, "Invalid padding" unless valid
      unpadded.force_encoding('UTF-8')
    end

    def nip44_padded_length(unpadded_length)
      return 32 if unpadded_length <= 32
      next_power = 1 << (Math.log2(unpadded_length - 1).floor + 1)
      chunk = next_power <= 256 ? 32 : next_power / 8
      chunk * ((unpadded_length - 1) / chunk + 1)
    end

    # ChaCha20 is a stream cipher so the same operation encrypts and decrypts.
    # OpenSSL wants a 16-byte IV: 4-byte initial counter + 12-byte nonce
    def chacha20(key, nonce, data)
      cipher = OpenSSL::Cipher.new('chacha20')
      cipher.encrypt
      cipher.key = key
      cipher.iv = "\x00".b * 4 + nonce
      cipher.update(data) + cipher.final
    end

    def hmac_aad(key, message, aad)
      raise Error, "AAD must be 32 bytes" unless aad.bytesize == 32
      OpenSSL::HMAC.digest('SHA256', key, aad + message)
    end

    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize
      result = 0
      a.bytes.zip(b.bytes) { |x, y| result |= x ^ y }
      result == 0
    end

    def nip04_shared_key(private_key, public_key)
      ec = OpenSSL::PKey::EC.new('secp256k1')
      ec.private_key = OpenSSL::BN.new(private_key, 16)
      pub_key_bn = OpenSSL::BN.new("02#{public_key}", 16)
      secret_point = OpenSSL::PKey::EC::Point.new(ec.group, pub_key_bn)
      ec.dh_compute_key(secret_point)
    end
  end
end
