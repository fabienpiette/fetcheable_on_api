# frozen_string_literal: true

require 'fetcheable_on_api/filtreable'
require 'fetcheable_on_api/pagineable'
require 'fetcheable_on_api/sortable'
require 'fetcheable_on_api/version'
require 'active_support'

module FetcheableOnApi
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
    collection = apply_sort(collection)
    collection = apply_pagination(collection)
    apply_filters(collection)
  end
end

ActiveSupport.on_load :action_controller do
  include FetcheableOnApi
end
