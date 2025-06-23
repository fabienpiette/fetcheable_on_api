# frozen_string_literal: true

require "fetcheable_on_api/configuration"
require "fetcheable_on_api/filterable"
require "fetcheable_on_api/pageable"
require "fetcheable_on_api/sortable"
require "fetcheable_on_api/version"
require "active_support"
require "date"

# FetcheableOnApi provides standardized sorting, filtering and pagination for
# Rails API controllers following the JSONAPI specification.
#
# This gem automatically adds support for query parameters like:
# - `filter[attribute]=value` for filtering data
# - `sort=attribute1,-attribute2` for sorting (- prefix for descending)
# - `page[number]=1&page[size]=25` for pagination
#
# @example Basic usage in a controller
#   class UsersController < ApplicationController
#     # Configure allowed filters and sorts
#     filter_by :name, :email, :status
#     sort_by :name, :created_at, :updated_at
#     
#     def index
#       users = apply_fetcheable(User.all)
#       render json: users
#     end
#   end
#
# @example Using with associations
#   class PostsController < ApplicationController
#     filter_by :title
#     filter_by :author, class_name: User, as: 'name'
#     sort_by :title, :created_at
#     sort_by :author, class_name: User, as: 'name'
#     
#     def index
#       posts = apply_fetcheable(Post.joins(:author).includes(:author))
#       render json: posts
#     end
#   end
#
# @author Fabien Piette
# @since 0.1.0
module FetcheableOnApi
  # Global configuration settings for FetcheableOnApi.
  # This method provides access to the singleton configuration instance
  # that can be used to customize default behavior across the application.
  #
  # @example Set default pagination size
  #   FetcheableOnApi.configuration.pagination_default_size = 25
  #
  # @return [Configuration] The global configuration instance
  # @see Configuration
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configure FetcheableOnApi using a block.
  # This is the recommended way to set up configuration in an initializer.
  #
  # @example Set default pagination size in config/initializers/fetcheable_on_api.rb
  #   FetcheableOnApi.configure do |config|
  #     config.pagination_default_size = 50
  #   end
  #
  # @yield [Configuration] Gives the global configuration instance to the block
  # @see Configuration
  def self.configure
    yield(configuration)
  end

  # Custom exception classes for FetcheableOnApi-specific errors.
  # These inherit from standard Ruby exceptions but allow for more
  # specific error handling in applications using this gem.
  
  # Raised when invalid parameters are provided to filtering, sorting, or pagination
  # @example
  #   raise FetcheableOnApi::ArgumentError, "Invalid filter parameter type"
  ArgumentError = Class.new(ArgumentError)
  
  # Raised when a feature is not yet implemented or supported
  # @example  
  #   raise FetcheableOnApi::NotImplementedError, "Custom predicate not supported"
  NotImplementedError = Class.new(NotImplementedError)

  # Hook called when this module is included in a class.
  # Automatically includes the three main concern modules that provide
  # filtering, sorting, and pagination functionality.
  #
  # @param klass [Class] The class that is including FetcheableOnApi
  # @private
  def self.included(klass)
    klass.class_eval do
      include Filterable
      include Sortable
      include Pageable
    end
  end

  # Protected instance methods available to controllers that include this module

  protected

  # Apply filters, sorting, and pagination to a collection in sequence.
  # This is the main entry point for processing JSONAPI query parameters.
  # 
  # The operations are applied in this specific order:
  # 1. Filtering (apply_filters) - reduces the dataset
  # 2. Sorting (apply_sort) - orders the results  
  # 3. Pagination (apply_pagination) - limits and offsets for page
  #
  # @param collection [ActiveRecord::Relation] The base collection to process
  # @return [ActiveRecord::Relation] The processed collection with filters, sorting, and pagination applied
  #
  # @example Basic usage
  #   def index
  #     users = apply_fetcheable(User.all)
  #     render json: users
  #   end
  #
  # @example With joins for association filtering/sorting
  #   def index
  #     posts = apply_fetcheable(Post.joins(:author).includes(:author))
  #     render json: posts
  #   end
  def apply_fetcheable(collection)
    # Apply filtering first to reduce dataset size
    collection = apply_filters(collection)
    
    # Apply sorting to the filtered results
    collection = apply_sort(collection)

    # Apply pagination last to get the final page
    apply_pagination(collection)
  end

  # Validates that the specified parameter keys contain values of permitted types.
  # This is used internally by the filtering, sorting, and pagination modules
  # to ensure that malformed or malicious parameters don't cause errors.
  #
  # @param keys [Array<Symbol>] Path to the parameter to validate (e.g., [:filter], [:page, :number])
  # @param foa_permitted_types [Array<Class>] Array of allowed parameter types
  # @raise [FetcheableOnApi::ArgumentError] When parameter type is not in permitted types
  #
  # @example
  #   # Validates that params[:filter] is a Hash or ActionController::Parameters
  #   foa_valid_parameters!(:filter)
  #   
  #   # Validates that params[:sort] is a String
  #   foa_valid_parameters!(:sort, foa_permitted_types: [String])
  #
  # @private
  def foa_valid_parameters!(*keys, foa_permitted_types: foa_default_permitted_types)
    return if foa_valid_params_types(*keys, foa_permitted_types: foa_permitted_types)

    actual_type = params.dig(*keys).class
    raise FetcheableOnApi::ArgumentError,
          "Incorrect type #{actual_type} for params #{keys}"
  end

  # Checks if the parameter value at the specified keys matches any of the permitted types.
  #
  # @param keys [Array<Symbol>] Path to the parameter to check
  # @param foa_permitted_types [Array<Class>] Array of allowed parameter types  
  # @return [Boolean] True if the parameter type is valid, false otherwise
  # @private
  def foa_valid_params_types(*keys, foa_permitted_types: foa_default_permitted_types)
    foa_permitted_types.inject(false) do |result, type|
      result || foa_valid_params_type(params.dig(*keys), type)
    end
  end

  # Checks if a value is of the specified type using Ruby's is_a? method.
  # This handles inheritance and module inclusion correctly.
  #
  # @param value [Object] The value to type-check
  # @param type [Class] The expected type/class
  # @return [Boolean] True if value is an instance of type (or its subclass/module)
  # @private
  def foa_valid_params_type(value, type)
    value.is_a?(type)
  end

  # Default permitted parameter types for most operations.
  # ActionController::Parameters is the standard Rails params object,
  # while Hash is allowed for direct hash parameters in tests or non-Rails usage.
  #
  # @return [Array<Class>] Array of default permitted parameter types
  # @private
  def foa_default_permitted_types
    [ActionController::Parameters, Hash]
  end

  # Convert string timestamp to DateTime object.
  # This is used for date/time filtering when the format is set to :datetime.
  # By default, it expects Unix epoch timestamps as strings.
  #
  # This method can be overridden in controllers to support different date formats:
  #
  # @param string [String] The timestamp string to convert
  # @return [DateTime] The parsed DateTime object
  #
  # @example Override in controller for custom date format
  #   class UsersController < ApplicationController
  #     private
  #     
  #     def foa_string_to_datetime(string)
  #       DateTime.strptime(string, '%Y-%m-%d %H:%M:%S')
  #     end
  #   end
  #
  # @example Default usage with epoch timestamps
  #   foa_string_to_datetime('1609459200') # => 2021-01-01 00:00:00 +0000
  def foa_string_to_datetime(string)
    DateTime.strptime(string, "%s")
  end
end

# Automatically include FetcheableOnApi in all ActionController classes when Rails loads.
# This makes the filtering, sorting, and pagination functionality available
# to all controllers without requiring manual inclusion.
#
# @note This uses ActiveSupport's lazy loading mechanism to ensure ActionController
#       is fully loaded before including the module.
ActiveSupport.on_load :action_controller do
  include FetcheableOnApi
end
