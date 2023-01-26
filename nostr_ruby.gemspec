$:.unshift File.expand_path('../lib', __FILE__)
require 'nostr_ruby/version'

Gem::Specification.new do |s|
  s.name          = 'nostr_ruby'
  s.version       = NostrRuby::VERSION
  s.summary       = 'A Ruby library to interact with the Nostr protocol'
  s.description   = 'This gem provides a simple class, MyGem, that can be used in other Ruby projects.'
  s.authors       = ['Daniele Tonon']
  s.homepage      = 'https://github.com/dtonon/nostr-ruby'
  s.licenses      = ['MIT']
  s.files         = Dir.glob('{bin/*,lib/**/*,[A-Z]*}')
  s.platform      = Gem::Platform::RUBY
  s.require_paths = ['lib']

  s.add_dependency 'base64', '~> 0.1.1'
  s.add_dependency 'bech32', '~> 1.3.0'
  s.add_dependency 'bip-schnorr', '~> 0.4.0'
  s.add_dependency 'json', '~> 2.6.2'
  s.add_dependency 'unicode-emoji', '~> 3.3.1'
  s.add_dependency 'websocket-client-simple', '~> 0.6.0'
end
