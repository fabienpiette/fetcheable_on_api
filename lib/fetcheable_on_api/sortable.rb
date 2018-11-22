# frozen_string_literal: true

module FetcheableOnApi
  module Sortable
    #
    # Supports
    #
    SORT_ORDER = {
      '+' => :asc,
      '-' => :desc
    }

    #
    # Public class methods
    #
    def self.included(base)
      base.class_eval do
        extend ClassMethods
        class_attribute :sorts_configuration, :instance_writer => false
        self.sorts_configuration = {}
      end
    end

    module ClassMethods
      def sort_by(*attrs)
        options = attrs.extract_options!
        options.symbolize_keys!

        self.sorts_configuration = sorts_configuration.dup

        attrs.each do |attr|
          sorts_configuration[attr] ||= {
            as: attr
          }

          sorts_configuration[attr] = self.sorts_configuration[attr].merge(options)
        end
      end
    end

    #
    # Public instance methods
    #

    #
    # Protected instance methods
    #
    protected

    def apply_sort(collection)
      return collection unless valid_parameters?(params)
      return collection unless valid_parameters?(params[:sort])

      return collection if params[:sort].blank?

      ordering      = {}
      sorted_params = params[:sort].split(',')

      sorted_params.each do |attr|
        sort_sign = (attr =~ /\A[+-]/) ? attr.slice!(0) : '+'
        klass     = collection.klass

        if klass.attribute_names.include?(attr)
          ordering[attr] = SORT_ORDER[sort_sign]
        end
      end

      ordering.select! do |attr|
        sorts_configuration.key?(attr.to_sym)
      end

      collection.order(ordering)
    end
  end
end
