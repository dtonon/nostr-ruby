require 'minitest/autorun'
require_relative '../lib/nostr_ruby'

# Official NIP-44 v2 test vectors from https://github.com/paulmillr/nip44
class Nip44Test < Minitest::Test
  VECTORS = JSON.parse(File.read(File.join(__dir__, 'nip44.vectors.json')))['v2']

  def hex(binary)
    binary.unpack1('H*')
  end

  def bin(hex)
    [hex].pack('H*')
  end

  def test_conversation_key_derivation
    VECTORS['valid']['get_conversation_key'].each do |v|
      key = CryptoTools.nip44_conversation_key(v['sec1'], v['pub2'])
      assert_equal v['conversation_key'], hex(key)
    end
  end

  def test_message_keys_derivation
    conversation_key = bin(VECTORS['valid']['get_message_keys']['conversation_key'])
    VECTORS['valid']['get_message_keys']['keys'].each do |v|
      chacha_key, chacha_nonce, hmac_key =
        CryptoTools.send(:nip44_message_keys, conversation_key, bin(v['nonce']))
      assert_equal v['chacha_key'], hex(chacha_key)
      assert_equal v['chacha_nonce'], hex(chacha_nonce)
      assert_equal v['hmac_key'], hex(hmac_key)
    end
  end

  def test_padded_length
    VECTORS['valid']['calc_padded_len'].each do |unpadded, padded|
      assert_equal padded, CryptoTools.send(:nip44_padded_length, unpadded)
    end
  end

  def test_encrypt_decrypt
    VECTORS['valid']['encrypt_decrypt'].each do |v|
      pub2 = Nostr::Key.get_public_key(v['sec2'])
      conversation_key = CryptoTools.nip44_conversation_key(v['sec1'], pub2)
      assert_equal v['conversation_key'], hex(conversation_key)

      payload = CryptoTools.nip44_encrypt(conversation_key, v['plaintext'], nonce: bin(v['nonce']))
      assert_equal v['payload'], payload

      assert_equal v['plaintext'], CryptoTools.nip44_decrypt(conversation_key, v['payload'])
    end
  end

  def test_encrypt_decrypt_long_messages
    VECTORS['valid']['encrypt_decrypt_long_msg'].each do |v|
      conversation_key = bin(v['conversation_key'])
      plaintext = v['pattern'] * v['repeat']
      assert_equal v['plaintext_sha256'], Digest::SHA256.hexdigest(plaintext)

      payload = CryptoTools.nip44_encrypt(conversation_key, plaintext, nonce: bin(v['nonce']))
      assert_equal v['payload_sha256'], Digest::SHA256.hexdigest(payload)

      assert_equal plaintext, CryptoTools.nip44_decrypt(conversation_key, payload)
    end
  end

  def test_invalid_plaintext_lengths
    conversation_key = SecureRandom.bytes(32)
    VECTORS['invalid']['encrypt_msg_lengths'].each do |length|
      assert_raises(CryptoTools::Error) do
        CryptoTools.nip44_encrypt(conversation_key, 'x' * length)
      end
    end
  end

  def test_invalid_conversation_keys
    VECTORS['invalid']['get_conversation_key'].each do |v|
      assert_raises(CryptoTools::Error, v['note']) do
        CryptoTools.nip44_conversation_key(v['sec1'], v['pub2'])
      end
    end
  end

  def test_invalid_decrypt
    VECTORS['invalid']['decrypt'].each do |v|
      assert_raises(CryptoTools::Error, v['note']) do
        CryptoTools.nip44_decrypt(bin(v['conversation_key']), v['payload'])
      end
    end
  end
end
