# frozen_string_literal: true

require 'active_call'
require 'faraday'
require 'faraday/retry'
require 'faraday/logging/color_formatter'

loader = Zeitwerk::Loader.for_gem
loader.setup

require_relative 'api/version'

module ActiveCall
  module Api
    class Error < StandardError; end
  end
end
