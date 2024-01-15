# Nostr Ruby Ideas

Ideas on how to change the interface of the Nostr Ruby gem to make it more easy to work with (and develop on).

## Getting started

```rb
# Initialize the client
# Should be a singleton
nostr = Nostr.new(relays: ["wss://relay.nostr.band", ...], private_key "nsec1...", opts = {})
```

## Signers

Handles the various ways that you can sign events

```rb
# Private key - this would be loaded from an env variable or secure location
nostr.private_key = "nsec1..."

# Nip-07
# Not sure yet...maybe not possible given ruby doesn't run client-side

# Remote signers - publishing events via nsecbunker or similar
# Not sure yet...this should be straightforward though.
```

## Users

Anything related to Users

```rb
# Fetch a user
# By pubkey, npub, or nip05
user = Nostr::User.find(pubkey: "pubkey", npub: "npub", nip05: "nip05@nip.com", opts = {})

# Access a user's profile info
# Profile info should be loaded as soon as a user is fetched
user.profile.name
user.profile.image

# Create a new keypair (user)
# Pass in attributes to also populate fields on a Kind: 0 metadata event
user = Nostr::User.new(attributes = {}, opts = {})

# Zap a user
user.zap(1337, "Zap comment")
```

## Events

Anything related to once-off event queries, event creation and publishing.

```rb
# Fetch all events matching a filter
events = Nostr::Event.where(filter = {}, opts = {})

# Fetch one event (the first returned) matching a filter
event = Nostr::Event.find(filter = {}, opts = {})

# Create new event
event = Nostr::Event.new(attributes = {}, opt = {})

# Sign an event
event.sign

# Publish (sign and broadcast to relays)
event.publish

# Encrypt/Decrypt an event Nip-04 style
event.encrypt(recipient: "pubkey")
event.decrypt(sender: "pubkey")

# React to an event
event.react("🤙")

# Zap an event
event.zap(1337, "Zap comment")
```

## Search

Search for events or users

```rb
# Limit to Kind 0 results
user_results = Nostr::User.search(search_terms: "JeffG", opts = {})

# Don't limit results to kind 0 results
event_results = Nostr::Event.search(search_terms: "JeffG", opts = {})

# Options would be things like kind, date ranges, etc.
```

## Subscriptions

Subscribe to a filter to keep new events flowing

```rb
# Create a new subscription, passing in a method to be executed when a new event happens.
sub = Nostr::Subscription.new(filter = {}, opts = {}, callback: Proc.new {})
sub.start

# Or, create new sub and start in one method
sub = Nostr::Subscription.create(filter = {}, opts = {}, callback: Proc.new {})
```

## Relays & Pools

TODO
