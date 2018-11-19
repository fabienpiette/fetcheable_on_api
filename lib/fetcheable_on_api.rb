# frozen_string_literal: true

require 'fetcheable_on_api/configuration'
require 'fetcheable_on_api/filtreable'
require 'fetcheable_on_api/pagineable'
require 'fetcheable_on_api/sortable'
require 'fetcheable_on_api/version'
require 'active_support'

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
end

ActiveSupport.on_load :action_controller do
  include FetcheableOnApi
end
