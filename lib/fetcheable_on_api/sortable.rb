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
      return collection if params[:sort].blank?
      foa_valid_parameters!(:sort, foa_permitted_types: [String])

      ordering = []

      clean_params(params[:sort]).each do |attr|
        klass = sorts_configuration[attr.to_sym].fetch(:class_name, collection.klass)
        field = sorts_configuration[attr.to_sym].fetch(:as, attr.to_sym).to_s
        next unless klass.attribute_names.include?(field)

        sort_sign = (attr =~ /\A[+-]/) ? attr.slice!(0) : '+'
        ordering << klass
                      .arel_table[field]
                      .send(SORT_ORDER[sort_sign])
      end

      collection.order(ordering)
    end

    private

    def clean_params(params)
      params
        .split(',')
        .select { |e| sorts_configuration.keys.map(&:to_s).include?(e) }
    end
  end
end
