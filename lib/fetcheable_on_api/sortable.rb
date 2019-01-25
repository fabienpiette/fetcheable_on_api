# frozen_string_literal: true

module FetcheableOnApi
  # Sortable implements `pagination` support.
  module Sortable
    #
    # Map of symbol to sorting direction supported by the module.
    #
    SORT_ORDER = {
      "+" => :asc,
      "-" => :desc,
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

    # Class methods made available to your controllers.
    module ClassMethods
      # Define one ore more sortable attribute configurations.
      #
      # @param attrs [Array] options to define one or more sorting
      #   configurations.
      # @option attrs [String, nil] :as Alias the sorted attribute
      # @option attrs [true, false, nil] :with Wether to sort on the lowercase
      #   attribute value.
      def sort_by(*attrs)
        options = attrs.extract_options!
        options.symbolize_keys!

        self.sorts_configuration = sorts_configuration.dup

        attrs.each do |attr|
          sorts_configuration[attr] ||= {
            as: attr,
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
        arel_sort(attr_name, sort_method, collection)
      end

      collection.order(ordering.compact)
    end

    private

    def arel_sort(attr_name, sort_method, collection)
      return if sorts_configuration[attr_name].blank?

      klass = class_for(attr_name, collection)
      field = field_for(attr_name)
      return unless belong_to_attributes_for?(klass, field)

      attribute = klass.arel_table[field]
      attribute = attribute.lower if sorts_configuration[attr_name].fetch(:lower, false)

      attribute.send(sort_method)
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
        .split(",")
        .each do |attribute|
        sort_sign = attribute =~ /\A[+-]/ ? attribute.slice!(0) : "+"
        res[attribute.to_sym] = SORT_ORDER[sort_sign]
      end
      res
    end
  end
end
