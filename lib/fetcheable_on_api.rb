# frozen_string_literal: true

require "fetcheable_on_api/configuration"
require "fetcheable_on_api/filterable"
require "fetcheable_on_api/pageable"
require "fetcheable_on_api/sortable"
require "fetcheable_on_api/version"
require "active_support"
require "date"

# FetcheableOnApi provides standardized sorting, filtering and pagination for
# you API controllers.
#
module FetcheableOnApi
  #
  # Global configuration settings for FetcheableOnApi
  #
  # @example Set default pagination size
  #   FetcheableOnApi.configuration.pagination_default_size = 25
  #
  # @return [Configuration] The global configuration instance
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configure FetcheableOnApi using a block.
  #
  # @example Set default pagination size
  #   FetcheableOnApi.configure do |config|
  #     config.pagination_default_size = 25
  #   end
  #
  # @yield [Configuration] Gives the global instance to the block.
  def self.configure
    yield(configuration)
  end

  #
  # Supports
  #
  ArgumentError = Class.new(ArgumentError)
  NotImplementedError = Class.new(NotImplementedError)

  #
  # Public class methods
  #
  def self.included(klass)
    klass.class_eval do
      include Filterable
      include Sortable
      include Pageable
    end
  end

  #
  # Public instance methods
  #

  #
  # Protected instance methods
  #
  protected

  # Apply filters, sort and page on a collection.
  def apply_fetcheable(collection)
    collection = apply_filters(collection)
    collection = apply_sort(collection)

    apply_pagination(collection)
  end

  # Checks if the type of arguments is included in the permitted types
  def foa_valid_parameters!(
                            *keys, foa_permitted_types: foa_default_permitted_types)
    return if foa_valid_params_types(
      *keys,
    foa_permitted_types: foa_permitted_types,
    )

    raise FetcheableOnApi::ArgumentError,
          "Incorrect type #{params.dig(*keys).class} for params #{keys}"
  end

  def foa_valid_params_types(
                             *keys, foa_permitted_types: foa_default_permitted_types)
    foa_permitted_types.inject(false) do |res, type|
      res || foa_valid_params_type(params.dig(*keys), type)
    end
  end

  # Returns true if class is the class of value,
  # or if class is one of the superclasses of value
  # or modules included in value.
  def foa_valid_params_type(value, type)
    value.is_a?(type)
  end

  # Types allowed by default.
  def foa_default_permitted_types
    [ActionController::Parameters, Hash]
  end

  # Convert string to datetime.
  def foa_string_to_datetime(string)
    DateTime.strptime(string, "%s")
  end
end

ActiveSupport.on_load :action_controller do
  include FetcheableOnApi
end
