# frozen_string_literal: true

require 'fetcheable_on_api/configuration'
require 'fetcheable_on_api/filtreable'
require 'fetcheable_on_api/pagineable'
require 'fetcheable_on_api/sortable'
require 'fetcheable_on_api/version'
require 'active_support'

module FetcheableOnApi
  ArgumentError = Class.new(ArgumentError)

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

  def valid_parameters!(*keys, permitted_types: default_permitted_types)
    raise FetcheableOnApi::ArgumentError.new(
      "Incorrect type #{params.dig(*keys).class} for params #{keys}"
    ) unless valid_params_types(*keys, permitted_types: permitted_types)
  end

  def valid_params_types(*keys, permitted_types: default_permitted_types)
    permitted_types.inject(false) do |res, type|
      res || valid_params_type(params.dig(*keys), type)
    end
  end

  def valid_params_type(value, type)
    value.is_a?(type)
  end

  def default_permitted_types
    [ActionController::Parameters, Hash]
  end
end

ActiveSupport.on_load :action_controller do
  include FetcheableOnApi
end
