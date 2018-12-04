# frozen_string_literal: true

module FetcheableOnApi
  module Filtreable
    #
    # Supports
    #

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

    module ClassMethods
      def filter_by(*attrs)
        options = attrs.extract_options!
        options.symbolize_keys!
        options.assert_valid_keys(:as, :class_name, :with, :format)

        self.filters_configuration = filters_configuration.dup

        attrs.each do |attr|
          filters_configuration[attr] ||= {
            as: options[:as] || attr
          }

          filters_configuration[attr] = filters_configuration[attr].merge(options)
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

    def try_parse_array(values, format)
      array = JSON.parse(values)
      array.map! { |el| foa_string_to_datetime(el.to_s) } if format == :datetime

      [array]
    rescue JSON::ParserError
      nil
    end

    def apply_filters(collection)
      return collection if params[:filter].blank?
      foa_valid_parameters!(:filter)

      filter_params = params.require(:filter)
                            .permit(filters_configuration.keys)
                            .to_hash

      filtering = filter_params.map do |column, values|
        format     = filters_configuration[column.to_sym].fetch(:format, :string)
        elements   = try_parse_array(values, format)
        elements ||= values.split(',')

        elements.map do |value|
          column_name = filters_configuration[column.to_sym].fetch(:as, column)
          klass       = filters_configuration[column.to_sym].fetch(:class_name, collection.klass)
          predicate   = filters_configuration[column.to_sym].fetch(:with, :ilike)

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
            raise ArgumentError, "unsupported predicate `#{predicate}`" unless predicate.respond_to?(:call)

            predicate.call(collection, value)
          end
        end.inject(:or)
      end

      collection.where(filtering.flatten.compact.inject(:and))
    end
  end
end
