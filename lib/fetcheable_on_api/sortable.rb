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
      format_params(params[:sort]).each do |attr, sort_method|
        next if sorts_configuration[attr].blank?

        klass = sorts_configuration[attr].fetch(:class_name, collection.klass)
        field = sorts_configuration[attr].fetch(:as, attr).to_s
        next unless klass.attribute_names.include?(field)

        ordering << klass
                    .arel_table[field]
                    .send(sort_method)
      end

      collection.order(ordering)
    end

    private

    # input: "-email,first_name"
    # return: { email: :desc, first_name: :asc }
    def format_params(params)
      res = {}
      params
        .split(',')
        .each do |attr|
          sort_sign = (attr =~ /\A[+-]/) ? attr.slice!(0) : '+'
          res[attr.to_sym] = SORT_ORDER[sort_sign]
        end
      res
    end
  end
end
