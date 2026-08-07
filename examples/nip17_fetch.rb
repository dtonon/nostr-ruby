#!/usr/bin/env ruby
# Fetch a NIP-17 direct message conversation with a counterparty
#
# Usage:
#   NSEC=nsec1... PEER=npub1... ruby examples/nip17_fetch.rb
#   NSEC=nsec1... PEER=<hex> RELAY=wss://relay1.com,wss://relay2.com ruby examples/nip17_fetch.rb
#
# Without RELAY the script discovers the DM relays (kind 10050) via an
# indexer relay. Both received and sent messages are gift wrapped to us,
# so the whole conversation is in our own kind 1059 events.

require_relative '../lib/nostr_ruby'

$stdout.sync = true

GIFT_WRAP_KIND = 1059
SEAL_KIND = 13
DM_KIND = 14
DM_RELAY_LIST_KIND = 10050
INDEXER_RELAY = 'wss://purplepag.es'

def fetch_events(relay:, filter:, timeout: 20)
  client = Nostr::Client.new(relay: relay)
  events = []
  client.on(:event) { |e| events << e }
  client.on(:eose) { client.close }
  client.on(:error) { |msg| warn "Relay error: #{msg}"; client.close }
  client.on(:connect) { client.subscribe(filter: filter) }
  client.connect
  deadline = Time.now + timeout
  sleep 0.2 while client.running? && Time.now < deadline
  client.close if client.running?
  # Let the EventMachine reactor stop completely before the
  # next connection starts one again
  sleep 0.1 while EM.reactor_running?
  events
end

key = ENV['NSEC'] or abort 'Set NSEC to your nsec (or hex private key)'
key = Nostr::Bech32.decode(key)[:data] if key.start_with?('nsec')
signer = Nostr::Signer.new(private_key: key)

peer = ENV['PEER'] or abort 'Set PEER to the counterparty npub (or hex pubkey)'
peer = Nostr::Bech32.decode(peer)[:data] if peer.start_with?('npub')

# The kind 10050 list usually lives on the user's own relays, not on
# indexers, so look for it on the indexer first and then on the NIP-65
# write relays; with no list at all fall back to the write relays
# themselves, where some clients store gift wraps anyway
def find_dm_relays(pubkey)
  lists = fetch_events(
    relay: INDEXER_RELAY,
    filter: Nostr::Filter.new(kinds: [DM_RELAY_LIST_KIND], authors: [pubkey], limit: 1)
  )
  dm_relays = extract_tags(lists, 'relay')
  return [dm_relays, :indexer] if dm_relays.any?

  nip65_lists = fetch_events(
    relay: INDEXER_RELAY,
    filter: Nostr::Filter.new(kinds: [10002], authors: [pubkey], limit: 1)
  )
  write_relays = (nip65_lists.first&.tags || [])
    .select { |t| t[0] == 'r' && (t[2].nil? || t[2] == 'write') }
    .map { |t| t[1] }
  return [[], :none] if write_relays.empty?

  write_relays.each do |relay|
    lists = begin
      fetch_events(
        relay: relay,
        filter: Nostr::Filter.new(kinds: [DM_RELAY_LIST_KIND], authors: [pubkey], limit: 1)
      )
    rescue StandardError
      []
    end
    dm_relays = extract_tags(lists, 'relay')
    return [dm_relays, :own_relay] if dm_relays.any?
  end

  [write_relays, :fallback]
end

def extract_tags(events, name)
  (events.first&.tags || []).select { |t| t[0] == name }.map { |t| t[1] }
end

relays = ENV['RELAY']&.split(',')
if relays.nil?
  relays, source = find_dm_relays(signer.public_key)
  abort 'No kind 10050 list and no NIP-65 relays found, set the RELAY env var' if relays.empty?
  if source == :fallback
    puts "No kind 10050 DM relay list found, trying the #{relays.size} NIP-65 write relays"
  else
    puts "Using #{relays.size} DM relays from kind 10050"
  end
end

# Gift wraps come from ephemeral pubkeys, so the sender cannot be
# filtered on the relay: fetch everything addressed to us and select
# the conversation after unwrapping
wraps_by_id = {}
relays.each do |relay|
  events = begin
    fetch_events(
      relay: relay,
      filter: Nostr::Filter.new(kinds: [GIFT_WRAP_KIND], p: [signer.public_key])
    )
  rescue StandardError => e
    warn "#{relay}: #{e.message}"
    []
  end
  puts "  #{relay}: #{events.size} gift wraps"
  events.each { |e| wraps_by_id[e.id] = e }
end

messages = []
failed = 0
wraps_by_id.each_value do |wrap|
  begin
    seal = JSON.parse(signer.nip44_decrypt(wrap.content, wrap.pubkey))
    raise "unexpected kind #{seal['kind']} in seal" unless seal['kind'] == SEAL_KIND

    rumor = JSON.parse(signer.nip44_decrypt(seal['content'], seal['pubkey']))
    # The seal signer must be the rumor author, or a sender could
    # impersonate someone else in the rumor
    raise 'seal and rumor pubkeys differ' unless rumor['pubkey'] == seal['pubkey']

    next unless rumor['kind'] == DM_KIND

    recipients = (rumor['tags'] || []).select { |t| t[0] == 'p' }.map { |t| t[1] }
    in_conversation =
      (rumor['pubkey'] == peer && recipients.include?(signer.public_key)) ||
      (rumor['pubkey'] == signer.public_key && recipients.include?(peer))
    messages << rumor if in_conversation
  rescue StandardError => e
    failed += 1
    warn "  Cannot unwrap #{wrap.id[0, 8]}: #{e.message}"
  end
end
puts "Unwrapped #{wraps_by_id.size - failed} of #{wraps_by_id.size} gift wraps"

messages.uniq! { |m| m['id'] || [m['pubkey'], m['created_at'], m['content']] }
messages.sort_by! { |m| m['created_at'] }

puts "#{messages.size} messages with #{Nostr::Bech32.encode_npub(peer)}"
messages.each do |m|
  who = m['pubkey'] == signer.public_key ? 'me' : 'them'
  time = Time.at(m['created_at']).strftime('%Y-%m-%d %H:%M')
  puts "[#{time}] #{who}: #{m['content']}"
end
