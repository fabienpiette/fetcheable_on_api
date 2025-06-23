require 'bundler/setup'
require 'fetcheable_on_api'
require 'active_support'
require 'active_support/core_ext'

# Load test helpers
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Enable mocking features
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Include test helpers
  config.include TestHelpers
end
