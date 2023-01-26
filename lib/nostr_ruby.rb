require 'custom_addr'
require 'ecdsa'
require 'schnorr'
require 'json'
require 'base64'
require 'bech32'
require 'unicode/emoji'
require 'websocket-client-simple'

# * Ruby library to interact with the Nostr protocol

class Nostr
  attr_reader :private_key, :public_key, :pow_difficulty_target

  def initialize(key)
    hex_private_key =  if key[:private_key]&.include?('nsec')
      Nostr.to_hex(key[:private_key])
    else
      key[:private_key]
    end

    hex_public_key = if key[:public_key]&.include?('npub')
      Nostr.to_hex(key[:public_key])
    else
      key[:public_key]
    end

    if hex_private_key
      @private_key = hex_private_key
      group = ECDSA::Group::Secp256k1
      @public_key = group.generator.multiply_by_scalar(private_key.to_i(16)).x.to_s(16)
    elsif hex_public_key
      @public_key = hex_public_key
    else
      raise 'Missing private or public key'
    end
  end

  def keys
    keys = { public_key: @public_key }
    keys[:private_key] = @private_key if @private_key
    keys
  end

  def bech32_keys
    bech32_keys = { public_key: Nostr.to_bech32(@public_key, 'npub') }
    bech32_keys[:private_key] = Nostr.to_bech32(@private_key, 'nsec') if @private_key
    bech32_keys
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

  def calculate_shared_key(other_public_key)
    ec = OpenSSL::PKey::EC.new('secp256k1')
    ec.private_key = OpenSSL::BN.new(@private_key, 16)
    recipient_key_hex = "02#{other_public_key}"
    recipient_pub_bn = OpenSSL::BN.new(recipient_key_hex, 16)
    secret_point = OpenSSL::PKey::EC::Point.new(ec.group, recipient_pub_bn)
    ec.dh_compute_key(secret_point)
  end

  def sign_event(event)
    raise 'Invalid pubkey' unless event[:pubkey].is_a?(String) && event[:pubkey].size == 64
    raise 'Invalid created_at' unless event[:created_at].is_a?(Integer)
    raise 'Invalid kind' unless (0..29_999).include?(event[:kind])
    raise 'Invalid tags' unless event[:tags].is_a?(Array)
    raise 'Invalid content' unless event[:content].is_a?(String)

    serialized_event = [
      0,
      event[:pubkey],
      event[:created_at],
      event[:kind],
      event[:tags],
      event[:content]
    ]

    serialized_event_sha256 = nil
    if @pow_difficulty_target
      nonce = 1
      loop do
        nonce_tag = ['nonce', nonce.to_s, @pow_difficulty_target.to_s]
        nonced_serialized_event = serialized_event.clone
        nonced_serialized_event[4] = nonced_serialized_event[4] + [nonce_tag]
        serialized_event_sha256 = Digest::SHA256.hexdigest(JSON.dump(nonced_serialized_event))
        if match_pow_difficulty?(serialized_event_sha256)
          event[:tags] << nonce_tag
          break
        end
        nonce += 1
      end
    else
      serialized_event_sha256 = Digest::SHA256.hexdigest(JSON.dump(serialized_event))
    end

    private_key = Array(@private_key).pack('H*')
    message = Array(serialized_event_sha256).pack('H*')
    event_signature = Schnorr.sign(message, private_key).encode.unpack('H*')[0]

    event['id'] = serialized_event_sha256
    event['sig'] = event_signature
    event
  end

  def build_event(payload)
    event = sign_event(payload)
    ['EVENT', event]
  end

  def build_metadata_event(name, about, picture, nip05)
    data = {}
    data[:name] = name if name
    data[:about] = about if about
    data[:picture] = picture if picture
    data[:nip05] = nip05 if nip05
    event = {
      "pubkey": @public_key,
      "created_at": Time.now.utc.to_i,
      "kind": 0,
      "tags": [],
      "content": data.to_json
    }

    event = sign_event(event)
    ['EVENT', event]
  end

  def build_note_event(text, channel_key = nil)
    event = {
      "pubkey": @public_key,
      "created_at": Time.now.utc.to_i,
      "kind": channel_key ? 42 : 1,
      "tags": channel_key ? [['e', channel_key]] : [],
      "content": text
    }

    event = sign_event(event)
    ['EVENT', event]
  end

  def build_recommended_relay_event(relay)
    raise 'Invalid relay' unless relay.start_with?('wss://') || relay.start_with?('ws://')

    event = {
      "pubkey": @public_key,
      "created_at": Time.now.utc.to_i,
      "kind": 2,
      "tags": [],
      "content": relay
    }

    event = sign_event(event)
    ['EVENT', event]
  end

  def build_contact_list_event(contacts)
    event = {
      "pubkey": @public_key,
      "created_at": Time.now.utc.to_i,
      "kind": 3,
      "tags": contacts.map { |c| ['p'] + c },
      "content": ''
    }

    event = sign_event(event)
    ['EVENT', event]
  end

  def build_dm_event(text, recipient_public_key)
    cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    cipher.encrypt
    cipher.iv = iv = cipher.random_iv
    cipher.key = calculate_shared_key(recipient_public_key)
    encrypted_text = cipher.update(text)
    encrypted_text << cipher.final
    encrypted_text = "#{Base64.encode64(encrypted_text)}?iv=#{Base64.encode64(iv)}"
    encrypted_text = encrypted_text.gsub("\n", '')

    event = {
      "pubkey": @public_key,
      "created_at": Time.now.utc.to_i,
      "kind": 4,
      "tags": [['p', recipient_public_key]],
      "content": encrypted_text
    }

    event = sign_event(event)
    ['EVENT', event]
  end

  def build_deletion_event(events, reason = '')
    event = {
      "pubkey": @public_key,
      "created_at": Time.now.utc.to_i,
      "kind": 5,
      "tags": events.map{ |e| ['e', e] },
      "content": reason
    }

    event = sign_event(event)
    ['EVENT', event]
  end

  def build_reaction_event(reaction, event, author)
    raise 'Invalid reaction' unless ['+', '-'].include?(reaction) || reaction.match?(Unicode::Emoji::REGEX)
    raise 'Invalid author' unless event.is_a?(String) && event.size == 64
    raise 'Invalid event' unless author.is_a?(String) && author.size == 64

    event = {
      "pubkey": @public_key,
      "created_at": Time.now.utc.to_i,
      "kind": 7,
      "tags": [['e', event], ['p', author]],
      "content": reaction
    }

    event = sign_event(event)
    ['EVENT', event]
  end

  def decrypt_dm(event)
    data = event[2]
    sender_public_key = dat['pubkey']
    encrypted = data['content'].split('?iv=')[0]
    iv = data['content'].split('?iv=')[1]
    cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    cipher.decrypt
    cipher.iv = Base64.decode64(iv)
    cipher.key = calculate_shared_key(sender_public_key)
    (cipher.update(Base64.decode64(encrypted)) + cipher.final).force_encoding('UTF-8')
  end

  def build_req_event(filters)
    ['REQ', SecureRandom.random_number.to_s, filters]
  end

  def build_close_event(subscription_id)
    ['CLOSE', subscription_id]
  end

  def build_notice_event(message)
    ['NOTICE', message]
  end

  def match_pow_difficulty?(event_id)
    @pow_difficulty_target.nil? || @pow_difficulty_target == [event_id].pack("H*").unpack("B*")[0].index('1')
  end

  def set_pow_difficulty_target(n)
    @pow_difficulty_target = n
  end

  def test_post_event(event, relay)
    response = nil
    ws = WebSocket::Client::Simple.connect relay
    ws.on :message do |msg|
      puts msg
      response = JSON.parse(msg.data)
      ws.close
    end
    ws.on :open do
      ws.send event.to_json
    end
    while response.nil? do
      sleep 0.1
    end
    response[0] == 'OK'
  end

end