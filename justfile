version := `ruby -e "require './lib/version'; puts Nostr::VERSION"`

build:
    gem build nostr_ruby.gemspec

publish: build
    gem push nostr_ruby-{{version}}.gem
