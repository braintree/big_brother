# BigBrother

[![Build Status](https://secure.travis-ci.org/braintree/big_brother.png)](http://travis-ci.org/braintree/big_brother)

Big_brother is an application to manage the weights of servers on an IPVS load balancer.  It is designed to talk to litmus_paper (https://github.com/braintree/litmus_paper).

## Build a deb

- Update `debian/changelog`
- Run `dpgk-buildpackage -uc -us`
- [There is no step three](https://www.youtube.com/watch?v=6uXJlX50Lj8).

## Installation

Add this line to your application's Gemfile:

    gem 'big_brother'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install big_brother

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
