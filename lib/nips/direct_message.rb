module Nostr
  class DirectMessage < Nostr::Event

    attr_reader :recipient

    def initialize(
      pubkey,
      content,
      recipient
    )
      tags = []
      @recipient = recipient
      tags << ['p', @recipient]
      super(
        Nostr::DIRECT_MESSAGE_KIND,
        pubkey,
        Time.now.utc.to_i,
        tags,
        content,
        {nip4_recipient: @recipient}
      )
    end

    def decrypt(private_key)
      data = @encrypted_content.split('?iv=')[0]
      iv = @encrypted_content.split('?iv=')[1]
      @content = CryptoTools.aes_256_cbc_decrypt(private_key, @recipient, data, iv)
    end

  end
end