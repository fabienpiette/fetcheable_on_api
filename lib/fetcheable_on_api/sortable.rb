# frozen_string_literal: true

module FetcheableOnApi
  # Application of a sorting on a collection
  module Sortable
    #
    # Supports
    #
    SORT_ORDER = {
      '+' => :asc,
      '-' => :desc
    }.freeze

    #
    # Public class methods
    #
    def self.included(base)
      base.class_eval do
        extend ClassMethods
        class_attribute :sorts_configuration, instance_writer: false
        self.sorts_configuration = {}
      end
    end

    # Detects url parameters and applies sorting
    module ClassMethods
      def sort_by(*attrs)
        options = attrs.extract_options!
        options.symbolize_keys!

        self.sorts_configuration = sorts_configuration.dup

        attrs.each do |attr|
          sorts_configuration[attr] ||= {
            as: attr
          }

          sorts_configuration[attr] = sorts_configuration[attr].merge(options)
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
      return collection if params[:sort].blank?

      foa_valid_parameters!(:sort, foa_permitted_types: [String])

      ordering = format_params(params[:sort]).map do |attr_name, sort_method|
        arel_sort(attr_name, sort_method)
      end

      collection.order(ordering.compact)
    end

    private

    def arel_sort(attr_name, sort_method)
      return if sorts_configuration[attr_name].blank?

      klass = class_for(attr_name, collection)
      field = field_for(attr_name)
      return unless belong_to_attributes_for?(klass, field)

      klass.arel_table[field].send(sort_method)
    end

    def class_for(attr_name, collection)
      sorts_configuration[attr_name].fetch(:class_name, collection.klass)
    end

    def field_for(attr_name)
      sorts_configuration[attr_name].fetch(:as, attr_name).to_s
    end

    def belong_to_attributes_for?(klass, field)
      klass.attribute_names.include?(field)
    end

    #
    # input: "-email,first_name"
    # return: { email: :desc, first_name: :asc }
    #
    def format_params(params)
      res = {}

      params
        .split(',')
        .each do |attribute|
          res[attribute.to_sym] = SORT_ORDER[sort_sign(attribute)]
        end
      res
    end

    def sort_sign(attribute)
      attribute =~ /\A[+-]/ ? attribute.slice!(0) : '+'
    end
  end
end
