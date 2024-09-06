# Nostr Ruby

A ruby library to interact with the [Nostr Protocol](https://github.com/nostr-protocol/nostr).

> [!Warning]
> This version in work in progress and breaks the v0.2.0 API


## Installation

Add this line to your application's Gemfile:

```ruby
# Gemfile
gem 'nostr_ruby'
```

And then execute:

```shell
$ bundle
```

Or install it yourself as:
```shell
$ gem install nostr_ruby
```

## Usage

### Manage keys

```ruby
require "nostr_ruby"

sk = Nostr::Key.generate_private_key
# => "8090fb3fe26e27d539ee349d70890d338c5e2e8b459e04c8e97658f03d2f9f33"

pk = Nostr::Key.get_public_key(sk)
# => "e7ded9bd42e7c74fcc6465962b919b7efcd5774ac6bea2ae6b81b2caa9d4d2e6"
```

### Decode entities

```ruby

puplic_key = Nostr::Bech32.decode(npub)
# => {:hrp=>"npub", :data=>"e7ded9bd42e7c74fcc6465962b919b7efcd5774ac6bea2ae6b81b2caa9d4d2e6"}

nprofile_data = Nostr::Bech32.decode("nprofile1qqs8hhhhhc3dmrje73squpz255ape7t448w86f7ltqemca7m0p99spgprpmhxue69uhkgar0dehkutnwdaehgu339e3k7mf06ras84")
# => {:hrp=>"nprofile", :data=>{:pubkey=>["7bdef7be22dd8e59f4600e044aa53a1cf975a9dc7d27df5833bc77db784a5805"], :relay=>["wss://dtonon.nostr1.com/"]}}

note_data = Nostr::Bech32.decode("note1xzce08egncw3mcm8l8edas6rrhgfj9l5uwwv2hz03zym0m9eg5hsxuyajp")
# => {:hrp=>"note", :data=>"30b1979f289e1d1de367f9f2dec3431dd09917f4e39cc55c4f8889b7ecb9452f"}

nevent_data = Nostr::Bech32.decode("nevent1qqsrpvvhnu5fu8gaudnlnuk7cdp3m5yezl6w88x9t38c3zdhaju52tcpzpmhxue69uhkztnwdaejumr0dshsz9nhwden5te0vfjhvmewdehhxarjxyhxxmmd9uq3wamnwvaz7tmzd96xxmmfdejhytnnda3kjctv9ulrdeva")
# => {:hrp=>"nevent", :data=> {:id=>["30b1979f289e1d1de367f9f2dec3431dd09917f4e39cc55c4f8889b7ecb9452f"], :relay=>["wss://a.nos.lol/", "wss://bevo.nostr1.com/", "wss://bitcoiner.social/"]}}

naddr_data = Nostr::Bech32.decode("naddr1qvzqqqr4gupzq77777lz9hvwt86xqrsyf2jn588ewk5aclf8mavr80rhmduy5kq9qqdkc6t5w3kx2ttvdamx2ttxdaez6mr0denj6en0wfkkzaqxq5r99")
# => => {:hrp=>"naddr", :data=>{:kind=>[30023], :author=>["7bdef7be22dd8e59f4600e044aa53a1cf975a9dc7d27df5833bc77db784a5805"], :identifier=>["little-love-for-long-format"]}}
```

### Encode entities

```ruby

nsec = Nostr::Bech32.encode_nsec(sk)
# => "nsec1szg0k0lzdcna2w0wxjwhpzgdxwx9ut5tgk0qfj8fwev0q0f0nuessml5ur"

npub = Nostr::Bech32.encode_npub(pk)
# => "npub1ul0dn02zulr5lnryvktzhyvm0m7d2a62c6l29tntsxev42w56tnqksrtfu"

nprofile = Nostr::Bech32.encode_nprofile(
  pubkey: "7bdef7be22dd8e59f4600e044aa53a1cf975a9dc7d27df5833bc77db784a5805",
  relays: ["wss://dtonon.nostr1.com"],
)
# => "nprofile1qqs8hhhhhc3dmrje73squpz255ape7t448w86f7ltqemca7m0p99spgpzamhxue69uhkgar0dehkutnwdaehgu339e3k7mg60me8x"

note = Nostr::Bech32.encode_note("30b1979f289e1d1de367f9f2dec3431dd09917f4e39cc55c4f8889b7ecb9452f")
# => "note1xzce08egncw3mcm8l8edas6rrhgfj9l5uwwv2hz03zym0m9eg5hsxuyajp"

nevent = Nostr::Bech32.encode_nevent(
  id: "30b1979f289e1d1de367f9f2dec3431dd09917f4e39cc55c4f8889b7ecb9452f",
  relays: ["wss://nos.lol"],
)
# => "nevent1qqsrpvvhnu5fu8gaudnlnuk7cdp3m5yezl6w88x9t38c3zdhaju52tcpp4mhxue69uhkummn9ekx7mqrqsqqqqqpux7e9q"

naddr = Nostr::Bech32.encode_naddr(
  author: "7bdef7be22dd8e59f4600e044aa53a1cf975a9dc7d27df5833bc77db784a5805",
  identifier: "little-love-for-long-format",
  kind: 30023
)
# => "naddr1qgs8hhhhhc3dmrje73squpz255ape7t448w86f7ltqemca7m0p99spgrqsqqqa28qqdkc6t5w3kx2ttvdamx2ttxdaez6mr0denj6en0wfkkzaqn2tjdj"
```

### Initialize a Client

```ruby
require "nostr_ruby"

c = Nostr::Client.new(private_key: Nostr::Key.generate_private_key)

c.private_key
# => "7402b4b1ee09fb37b64ec2a958f1b7815d904c6dd44227bdef7912ef201af97d"

c.public_key
# => "a19f3c16b6e857d2b673c67eea293431fc175895513ca2f687a717152a5da466"

c.nsec
# => "nsec1wsptfv0wp8an0djwc2543udhs9weqnrd63pz00000yfw7gq6l97snckpdq"

c.npub
# => "npub15x0nc94kapta9dnncelw52f5x87pwky42y729a585ut322ja53nq72yrcr"
```

### Create, sign and send an event

```ruby
# Initialize a client
c = Nostr::Client.new(private_key: 
"7402b4b1ee09fb37b64ec2a958f1b7815d904c6dd44227bdef7912ef201af97d")

# Initialize an event
e = Nostr::Event.new(
  kind: ...,
  pubkey: ...,
  created_at: ...,
  tags: ...,
  content: ...,
  pow: ...,
  delegation: ...,
  recipient: ...,
)

# Sign the event
c.sign(e)

# Send the event
c.send(e, "wss://nos.lol")

```

### Set the profile

```ruby
metadata = {
  name: "Mr Robot",
  about: "I walk around the city",
  picture: "https://upload.wikimedia.org/wikipedia/commons/3/35/Mr_robot_photo.jpg",
  nip05: "mrrobot@mrrobot.com"
}

e = Nostr::Event.new(
  kind: Nostr::Kind::METADATA,
  pubkey: c.public_key,
  content: metadata.to_json,
)
```

### Post a note
```ruby
e = Nostr::Event.new(
  kind: Nostr::Kind::SHORT_NOTE,
  pubkey: c.public_key,
  content: "Hello Nostr!",
)
```

### Share a contact list
```ruby
contact_list = [
  ["54399b6d8200813bfc53177ad4f13d6ab712b6b23f91aefbf5da45aeb5c96b08", "wss://alicerelay.com/", "alice"],
  ["850708b7099215bf9a1356d242c2354939e9a844c1359d3b5209592a0b420452", "wss://bobrelay.com/nostr", "bob"],
  ["f7f4b0072368460a09138bf3966fb1c59d0bdadfc3aff4e59e6896194594a82a", "ws://carolrelay.com/ws", "carol"]
]

e = Nostr::Event.new(
  kind: Nostr::Kind::CONTACT_LIST,
  pubkey: c.public_key,
  tags: contact_list.map { |c| ['p'] + c },
)
```

### Delete an event
```ruby
event_to_delete = "b91b3fb40128112c38dc54168b9f601c22bf8fcae6e70bb2a5f53e7f3ae44388"
e = Nostr::Event.new(
  kind: Nostr::Kind::DELETION,
  pubkey: c.public_key,
  tags: [["e", event_to_delete]],
)
```

### React to an event
```ruby
e = Nostr::Event.new(
  kind: Nostr::Kind::REACTION,
  pubkey: c.public_key,
  content: "+",
  tags: [["e", target_event]],
)

e2 = Nostr::Event.new(
  kind: Nostr::Kind::REACTION,
  pubkey: c.public_key,
  content: "🔥",
  tags: [["e", target_event]],
)
```

### Create events with a PoW difficulty
```ruby
# Just add the `pow` argument 
e = Nostr::Event.new(
  kind: Nostr::Kind::SHORT_NOTE,
  pubkey: c.public_key,
  content: "Hello Nostr!",
  pow: 15,
)
```

### Create a NIP-26 delegation and use it
```ruby
delegator = Nostr::Client.new(private_key: delegator_key)

delegatee = "b1d8dfd69fe8795042dbbc4d3f85938a01d4740c54d2daf11088c75c50ff19d9"
conditions = "kind=1&created_at>#{Time.now.to_i}&created_at<#{(Time.now + 60*60).to_i}"
delegation_tag = delegator.generate_delegation_tag(
  to: delegatee,
  conditions: conditions
)

# The `delegation_tag` is given to the delegatee so it can use it

delegatee = Nostr::Client.new(private_key: delegatee_key)

e = Nostr::Event.new(
  kind: Nostr::Kind::SHORT_NOTE,
  pubkey: delegatee.public_key,
  content: "Hello Nostr!",
  delegation: delegation_tag,
)

delegatee.sign(e)
```
### Send a direct message
Warning: This uses NIP-04, that will be deprecated in favor of NIP-17
```ruby
recipient = "npub1ul0dn02zulr5lnryvktzhyvm0m7d2a62c6l29tntsxev42w56tnqksrtfu"

e = Nostr::Event.new(
  kind: Nostr::Kind::DIRECT_MESSAGE,
  pubkey: c.public_key,
  recipient: Nostr::Bech32.decode(recipient)[:data],
  content: "Hello Alice!"
)

e = Nostr::Event.new(
  kind: Nostr::Kind::DIRECT_MESSAGE,
  pubkey: c.public_key,
  tags: [["p", Nostr::Bech32.decode(recipient)[:data]]],
  content: "Hello Alice!"
)
```

### Decrypt a direct message
Warning: This uses NIP-04, that will be deprecated in favor of NIP-17
```ruby
e = {
  :kind=>4,
  :pubkey=>"a19f3c16b6e857d2b673c67eea293431fc175895513ca2f687a717152a5da466",
  :created_at=>1725387307,
  :tags=>[["p", "e7ded9bd42e7c74fcc6465962b919b7efcd5774ac6bea2ae6b81b2caa9d4d2e6"]],
  :content=>"Nd7n/wId1oiprUCC4WWwNw==?iv=7gIRExcyO1xystretLIPnQ==",
  :id=>"b91b3fb40128112c38dc54168b9f601c22bf8fcae6e70bb2a5f53e7f3ae44388",
  :sig=>"73edf5a6acbefdd3d76f28ba90faaabe348a24c798f8fa33797eec29e2404c33a455815a59472ecd023441df38d815f83d81b95b8cb2f2c88a52982c8f7301e9"
}

c.decrypt(e)
puts e.content
=> "Hello Alice!"
```