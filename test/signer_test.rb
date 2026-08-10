require 'minitest/autorun'
require_relative '../lib/nostr_ruby'

class SignerTest < Minitest::Test
  def setup
    @alice = Nostr::Signer.new(private_key: Nostr::Key.generate_private_key)
    @bob = Nostr::Signer.new(private_key: Nostr::Key.generate_private_key)
  end

  def test_nip44_roundtrip_between_parties
    payload = @alice.nip44_encrypt("hello bob", @bob.public_key)
    assert_equal "hello bob", @bob.nip44_decrypt(payload, @alice.public_key)
  end

  def test_nip44_roundtrip_to_self
    payload = @alice.nip44_encrypt("note to self")
    assert_equal "note to self", @alice.nip44_decrypt(payload)
  end

  def test_nip04_roundtrip
    payload = @alice.nip04_encrypt("hello bob", @bob.public_key)
    assert_equal "hello bob", @bob.nip04_decrypt(payload, @alice.public_key)
  end

  def test_nip04_dm_helper
    event = @alice.nip04_dm("hello bob", @bob.public_key)
    assert event.valid?
    assert_equal Nostr::Kind::DIRECT_MESSAGE, event.kind
    assert_equal [["p", @bob.public_key]], event.tags
    assert_equal "hello bob", @bob.nip04_decrypt(event.content, event.pubkey)
  end

  def test_plaintext_dm_is_not_signable
    event = Nostr::Event.new(
      kind: Nostr::Kind::DIRECT_MESSAGE,
      tags: [["p", @bob.public_key]],
      content: "plaintext leak"
    )
    error = assert_raises(Nostr::Event::ValidationError) { @alice.sign(event) }
    assert_match(/NIP-04 encrypted/, error.message)
  end
end
