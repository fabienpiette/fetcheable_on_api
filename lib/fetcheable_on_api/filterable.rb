# frozen_string_literal: true

module FetcheableOnApi
  # Filterable implements `filter` parameter support.
  module Filterable
    #
    # Predicates supported for filtering.
    #
    PREDICATES_WITH_ARRAY = %i[
      does_not_match_all
      does_not_match_any
      eq_all
      eq_any
      gt_all
      gt_any
      gteq_all
      gteq_any
      in_all
      in_any
      lt_all
      lt_any
      lteq_all
      lteq_any
      matches_all
      matches_any
      not_eq_all
      not_eq_any
      not_in_all
      not_in_any
    ].freeze

    #
    # Public class methods
    #
    def self.included(base)
      base.class_eval do
        extend ClassMethods
        class_attribute :filters_configuration, instance_writer: false
        self.filters_configuration = {}
      end
    end

    # Class methods made available to your controllers.
    module ClassMethods
      # Define a filterable attribute.
      #
      # @see FetcheableOnApi::Filterable::PREDICATES_WITH_ARRAY
      #
      # @param attrs [Array] options to define one or more filters.
      # @option attrs [String, nil] :as Alias the filtered attribute
      # @option attrs [String, nil] :class_name Override the class of the filter target
      # @option attrs [String, nil] :with Use a specific predicate
      def filter_by(*attrs)
        options = attrs.extract_options!
        options.symbolize_keys!
        options.assert_valid_keys(:as, :class_name, :with, :format)

        self.filters_configuration = filters_configuration.dup

        attrs.each do |attr|
          filters_configuration[attr] ||= {
            as: options[:as] || attr,
          }

          filters_configuration[attr].merge!(options)
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

    def valid_keys
      keys = filters_configuration.keys
      keys.each_with_index do |key, index|
        predicate = filters_configuration[key.to_sym].fetch(:with, :ilike)

        next if predicate.respond_to?(:call) ||
                PREDICATES_WITH_ARRAY.exclude?(predicate.to_sym)

        keys[index] = {key => []}
      end

      keys
    end

    def apply_filters(collection)
      return collection if params[:filter].blank?

      foa_valid_parameters!(:filter)

      filter_params = params.require(:filter)
                            .permit(valid_keys)
                            .to_hash

      filtering = filter_params.map do |column, values|
        format = filters_configuration[column.to_sym].fetch(:format, :string)
        column_name = filters_configuration[column.to_sym].fetch(:as, column)
        klass = filters_configuration[column.to_sym].fetch(:class_name, collection.klass)
        predicate = filters_configuration[column.to_sym].fetch(:with, :ilike)

        if %i[between not_between].include?(predicate)
          predicates(predicate, collection, klass, column_name, values.split(","))
        elsif values.is_a?(String)
          values.split(",").map do |value|
            predicates(predicate, collection, klass, column_name, value)
          end.inject(:or)
        else
          values.map! { |el| el.split(",") }
          predicates(predicate, collection, klass, column_name, values)
        end
      end

      collection.where(filtering.flatten.compact.inject(:and))
    end

    # Apply arel predicate on collection
    def predicates(predicate, collection, klass, column_name, value)
      case predicate
      when :between
        klass.arel_table[column_name].between(value.first..value.last)
      when :does_not_match
        klass.arel_table[column_name].does_not_match("%#{value}%")
      when :does_not_match_all
        klass.arel_table[column_name].does_not_match_all(value)
      when :does_not_match_any
        klass.arel_table[column_name].does_not_match_any(value)
      when :eq
        klass.arel_table[column_name].eq(value)
      when :eq_all
        klass.arel_table[column_name].eq_all(value)
      when :eq_any
        klass.arel_table[column_name].eq_any(value)
      when :gt
        klass.arel_table[column_name].gt(value)
      when :gt_all
        klass.arel_table[column_name].gt_all(value)
      when :gt_any
        klass.arel_table[column_name].gt_any(value)
      when :gteq
        klass.arel_table[column_name].gteq(value)
      when :gteq_all
        klass.arel_table[column_name].gteq_all(value)
      when :gteq_any
        klass.arel_table[column_name].gteq_any(value)
      when :in
        klass.arel_table[column_name].in(value)
      when :in_all
        klass.arel_table[column_name].in_all(value)
      when :in_any
        klass.arel_table[column_name].in_any(value)
      when :lt
        klass.arel_table[column_name].lt(value)
      when :lt_all
        klass.arel_table[column_name].lt_all(value)
      when :lt_any
        klass.arel_table[column_name].lt_any(value)
      when :lteq
        klass.arel_table[column_name].lteq(value)
      when :lteq_all
        klass.arel_table[column_name].lteq_all(value)
      when :lteq_any
        klass.arel_table[column_name].lteq_any(value)
      when :ilike
        klass.arel_table[column_name].matches("%#{value}%")
      when :matches
        klass.arel_table[column_name].matches(value)
      when :matches_all
        klass.arel_table[column_name].matches_all(value)
      when :matches_any
        klass.arel_table[column_name].matches_any(value)
      when :not_between
        klass.arel_table[column_name].not_between(value.first..value.last)
      when :not_eq
        klass.arel_table[column_name].not_eq(value)
      when :not_eq_all
        klass.arel_table[column_name].not_eq_all(value)
      when :not_eq_any
        klass.arel_table[column_name].not_eq_any(value)
      when :not_in
        klass.arel_table[column_name].not_in(value)
      when :not_in_all
        klass.arel_table[column_name].not_in_all(value)
      when :not_in_any
        klass.arel_table[column_name].not_in_any(value)
      else
        unless predicate.respond_to?(:call)
          raise ArgumentError,
                "unsupported predicate `#{predicate}`"
        end

        predicate.call(collection, value)
      end
    end

    # Types allowed by default for filter action.
    def foa_default_permitted_types
      [ActionController::Parameters, Hash, Array]
    end
  end
end
