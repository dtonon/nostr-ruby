#!/usr/bin/env ruby
# Verify the NIP-44 implementation against real Manent private notes
# (kind 33301, encrypted to self, https://github.com/dtonon/manent)
#
# Usage:
#   NSEC=nsec1... ruby examples/manent_fetch.rb
#   NSEC=nsec1... RELAY=wss://relay1.com,wss://relay2.com ruby examples/manent_fetch.rb
#
# Without RELAY the script discovers the write relays from the NIP-65
# relay list (kind 10002) via an indexer relay and queries them all.

require_relative '../lib/nostr_ruby'

$stdout.sync = true

MANENT_NOTE_KIND = 33301
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
puts "Checking Manent notes for #{signer.npub}"

relays = ENV['RELAY']&.split(',')
if relays.nil?
  relay_lists = fetch_events(
    relay: INDEXER_RELAY,
    filter: Nostr::Filter.new(kinds: [10002], authors: [signer.public_key], limit: 1)
  )
  tags = relay_lists.first&.tags || []
  relays = tags.select { |t| t[0] == 'r' && (t[2].nil? || t[2] == 'write') }.map { |t| t[1] }
  abort 'No NIP-65 write relay found, set the RELAY env var' if relays.empty?
  puts "Using #{relays.size} write relays from NIP-65"
end

# Collect from all relays, keeping only the newest version of each note
# (kind 33301 is addressable, so the d tag identifies the note)
notes_by_d = {}
relays.each do |relay|
  events = begin
    fetch_events(
      relay: relay,
      filter: Nostr::Filter.new(kinds: [MANENT_NOTE_KIND], authors: [signer.public_key])
    )
  rescue StandardError => e
    warn "#{relay}: #{e.message}"
    []
  end
  puts "  #{relay}: #{events.size} events"
  events.each do |event|
    d_tag = event.tags.find { |t| t[0] == 'd' }&.dig(1) || event.id
    current = notes_by_d[d_tag]
    notes_by_d[d_tag] = event if current.nil? || event.created_at > current.created_at
  end
end

notes = notes_by_d.values
puts "Found #{notes.size} unique Manent notes"

decrypted = 0
failed = 0
notes.sort_by(&:created_at).each do |event|
  begin
    plaintext = signer.nip44_decrypt(event.content)
    decrypted += 1
    date = Time.at(event.created_at).strftime('%Y-%m-%d')
    preview = plaintext[0, 60].gsub(/\s+/, ' ')
    puts "  OK #{date} #{preview}..."
  rescue StandardError => e
    failed += 1
    puts "  FAIL #{event.id[0, 8]}: #{e.class}: #{e.message}"
  end
end

puts "#{decrypted} decrypted, #{failed} failed"
exit(failed.zero? ? 0 : 1)
