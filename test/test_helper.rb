ENV["RAILS_ENV"] ||= "test"

if ENV["COVERAGE"] || ENV["CI"]
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch
    skip "/test/"
    skip "/config/"
    group "Domain Models", "app/models/backtest"
    group "Market Data", "app/models/market_data"
    group "Active Record Models", "app/models"
    group "Controllers", "app/controllers"
    group "Jobs", "app/jobs"
  end
end

require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    if ENV["COVERAGE"] || ENV["CI"]
      parallelize_setup do |worker|
        SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
      end

      parallelize_teardown do |_worker|
        SimpleCov.result
      end
    end

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
