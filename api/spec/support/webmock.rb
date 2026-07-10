# frozen_string_literal: true

require 'webmock/rspec'

# Disable external requests by default
WebMock.disable_net_connect!(allow_localhost: false)
