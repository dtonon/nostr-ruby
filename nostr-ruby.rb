require 'ecdsa'
require 'schnorr'
require 'json'
require 'base64'
require 'bech32'
require 'websocket-client-simple'

# * Ruby library to interact with the Nostr protocol

class Nostr
  attr_reader :private_key, :public_key, :relay_host

  def initialize(key, relay_host = nil)
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

    @relay_host = relay_host
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
    serialized_event = [
      0,
      event[:pubkey],
      event[:created_at],
      event[:kind],
      event[:tags],
      event[:content]
    ]

    serialized_event_json = JSON.dump(serialized_event)
    serialized_event_sha256 = Digest::SHA256.hexdigest(serialized_event_json)
    private_key = Array(@private_key).pack('H*')
    message = Array(serialized_event_sha256).pack('H*')
    event_signature = Schnorr.sign(message, private_key).encode.unpack('H*')[0]
    event['id'] = serialized_event_sha256
    event['sig'] = event_signature
    event
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
      "pubkey": recipient_public_key,
      "created_at": Time.now.utc.to_i,
      "kind": 4,
      "tags": [['p', recipient_public_key]],
      "content": encrypted_text
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

  def test_post_event(event)
    response = nil
    ws = WebSocket::Client::Simple.connect @relay_host
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

class CustomAddr

  attr_accessor :hrp # human-readable part
  attr_accessor :prog # witness program

  def initialize(addr = nil)
    @hrp, @prog = parse_addr(addr) if addr
  end

  def to_scriptpubkey
    prog.map{|p|[p].pack("C")}.join.unpack('H*').first
  end

  def scriptpubkey=(script)
    values = [script].pack('H*').unpack("C*")
    @prog = values
  end

  def addr
    spec = Bech32::Encoding::BECH32
    Bech32.encode(hrp, convert_bits(prog, 8, 5), spec)
  end

  private

  def parse_addr(addr)
    hrp, data, spec = Bech32.decode(addr)
    raise 'Invalid address.' if hrp.nil? || data[0].nil?
    # raise 'Invalid witness version' if ver > 16
    prog = convert_bits(data, 5, 8, false)
    # raise 'Invalid witness program' if prog.nil? || prog.length < 2 || prog.length > 40
    # raise 'Invalid witness program with version 0' if ver == 0 && (prog.length != 20 && prog.length != 32)
    [hrp, prog]
  end

  def convert_bits(data, from, to, padding=true)
    acc = 0
    bits = 0
    ret = []
    maxv = (1 << to) - 1
    max_acc = (1 << (from + to - 1)) - 1
    data.each do |v|
      return nil if v < 0 || (v >> from) != 0
      acc = ((acc << from) | v) & max_acc
      bits += from
      while bits >= to
        bits -= to
        ret << ((acc >> bits) & maxv)
      end
    end
    if padding
      ret << ((acc << (to - bits)) & maxv) unless bits == 0
    elsif bits >= from || ((acc << (to - bits)) & maxv) != 0
      return nil
    end
    ret
  end

end
