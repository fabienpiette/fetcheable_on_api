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
        class_attribute :filters_configuration, :instance_writer => false
        self.filters_configuration = {}
      end
    end

    module ClassMethods
      def filter_by(*attrs)
        options = attrs.extract_options!
        options.symbolize_keys!
        options.assert_valid_keys(:as, :class_name)

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

    def apply_filters(collection)
      return collection if params[:filter].blank?
      valid_parameters!(:filter)

      filter_params = params.require(:filter)
                            .permit(filters_configuration.keys)
                            .to_hash

      filtering = filter_params.map do |column, values|
        values.split(',').map do |value|
          column_name = filters_configuration[column.to_sym].fetch(:as, column)
          klass       = filters_configuration[column.to_sym].fetch(:class_name, collection.klass)

          klass.arel_table[column_name].matches("%#{value}%")
        end.inject(:or)
      end

      collection.where(filtering.flatten.compact.inject(:and))
    end
  end
end
