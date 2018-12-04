# frozen_string_literal: true

require 'fetcheable_on_api/configuration'
require 'fetcheable_on_api/filtreable'
require 'fetcheable_on_api/pagineable'
require 'fetcheable_on_api/sortable'
require 'fetcheable_on_api/version'
require 'active_support'
require 'date'

module FetcheableOnApi
  #
  # Configuration
  #
  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  #
  # Supports
  #
  ArgumentError       = Class.new(ArgumentError)
  NotImplementedError = Class.new(NotImplementedError)

  #
  # Public class methods
  #
  def self.included(klass)
    klass.class_eval do
      include Filtreable
      include Sortable
      include Pagineable
    end
  end

  #
  # Public instance methods
  #

  #
  # Protected instance methods
  #
  protected

  def apply_fetcheable(collection)
    collection = apply_filters(collection)
    collection = apply_sort(collection)

    apply_pagination(collection)
  end

  def foa_valid_parameters!(*keys, foa_permitted_types: foa_default_permitted_types)
    raise FetcheableOnApi::ArgumentError.new(
      "Incorrect type #{params.dig(*keys).class} for params #{keys}"
    ) unless foa_valid_params_types(*keys, foa_permitted_types: foa_permitted_types)
  end

  def foa_valid_params_types(*keys, foa_permitted_types: foa_default_permitted_types)
    foa_permitted_types.inject(false) do |res, type|
      res || foa_valid_params_type(params.dig(*keys), type)
    end
  end

  def foa_valid_params_type(value, type)
    value.is_a?(type)
  end

  def foa_default_permitted_types
    [ActionController::Parameters, Hash]
  end

  def foa_string_to_datetime(string)
    DateTime.strptime(string, '%s')
  end
end

ActiveSupport.on_load :action_controller do
  include FetcheableOnApi
end
