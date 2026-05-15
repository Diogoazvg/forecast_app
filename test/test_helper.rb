require 'simplecov'
SimpleCov.start 'rails' do
  # Change the output directory to /tmp
  coverage_dir '/tmp/coverage'
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Single worker keeps SimpleCov line counts accurate.
    parallelize(workers: 1)

    setup do
      Rails.cache.clear
    end
  end
end

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }
