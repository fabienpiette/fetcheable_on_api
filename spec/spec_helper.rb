require 'bundler/setup'
require 'active_support'

require 'rails'
Bundler.require :default, :development
Combustion.initialize! :active_record, :action_controller, :sprockets
require 'rspec/rails'

# Dir[Rails.root.join("spec/internal/**/*.rb")].each { |f| puts f;require f }
# require 'rails-controller-testing'
# Rails::Controller::Testing.install

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

require 'fetcheable_on_api'
