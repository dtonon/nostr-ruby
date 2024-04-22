require_relative 'version'
require_relative 'tools/custom_addr'
require_relative 'tools/crypto_tools'

require 'ecdsa'
require 'schnorr'
require 'json'
require 'base64'
require 'bech32'
require 'unicode/emoji'
require 'websocket-client-simple'

require_relative 'event'
require_relative 'client'
require_relative 'nips/metadata'
require_relative 'nips/short_note'
require_relative 'nips/direct_message'
require_relative 'nips/deletion'
require_relative 'nips/contact_list'
require_relative 'nips/reaction'

module Nostr
  METADATA_KIND = 0
  SHORT_NOTE_KIND = 1
  CONTACT_LIST_KIND = 3
  DIRECT_MESSAGE_KIND = 4
  DELETION_KIND = 5
  REACTION_KIND = 7
end