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

nsec = Nostr::Key.encode_private_key(sk)
# => "nsec1szg0k0lzdcna2w0wxjwhpzgdxwx9ut5tgk0qfj8fwev0q0f0nuessml5ur"

npub = Nostr::Key.encode_public_key(pk)
# => "npub1ul0dn02zulr5lnryvktzhyvm0m7d2a62c6l29tntsxev42w56tnqksrtfu"

hex = Nostr::Key.decode(npub)
# => "e7ded9bd42e7c74fcc6465962b919b7efcd5774ac6bea2ae6b81b2caa9d4d2e6"
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

### Create a note
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

### Create a direct message
```ruby
recipient = "npub1ul0dn02zulr5lnryvktzhyvm0m7d2a62c6l29tntsxev42w56tnqksrtfu"

e = Nostr::Event.new(
  kind: Nostr::Kind::DIRECT_MESSAGE,
  pubkey: c.public_key,
  recipient: recipient,
  content: "Hello Alice!"
)

e = Nostr::Event.new(
  kind: Nostr::Kind::DIRECT_MESSAGE,
  pubkey: c.public_key,
  tags: [["p", Nostr::Key.decode(recipient)]],
  content: "Hello Alice!"
)
```

### Decrypt a private message
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
)

e2 = Nostr::Event.new(
  kind: Nostr::Kind::REACTION,
  pubkey: c.public_key,
  content: "🔥",
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
