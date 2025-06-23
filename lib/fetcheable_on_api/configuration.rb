# frozen_string_literal: true

module FetcheableOnApi
  # Configuration class for FetcheableOnApi gem settings.
  #
  # This class holds global configuration options that affect the behavior
  # of filtering, sorting, and pagination across all controllers that use
  # the FetcheableOnApi module.
  #
  # Configuration is typically set in a Rails initializer file, but can
  # also be modified at runtime if needed.
  #
  # @example Setting configuration in an initializer
  #   # config/initializers/fetcheable_on_api.rb
  #   FetcheableOnApi.configure do |config|
  #     config.pagination_default_size = 50
  #   end
  #
  # @example Runtime configuration changes
  #   FetcheableOnApi.configuration.pagination_default_size = 100
  #
  # @since 0.1.0
  class Configuration
    # Default number of records per page when no page[size] parameter is provided.
    # This value is used by the Pageable module when clients don't specify
    # a page size in their requests.
    #
    # @return [Integer] The default pagination size
    # @example
    #   # With default configuration (25):
    #   # GET /users?page[number]=2
    #   # Returns 25 records starting from record 26
    #
    #   # With custom configuration (50):
    #   # GET /users?page[number]=2  
    #   # Returns 50 records starting from record 51
    attr_accessor :pagination_default_size

    # Initialize configuration with default values.
    # Sets up sensible defaults that work well for most applications.
    def initialize
      @pagination_default_size = 25
    end
  end
end
