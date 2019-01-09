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

      ordering = clean_params(params[:sort]).map do |attr|
        arel_sort(collection, attr)
      end

      collection.order(ordering)
    end

    private

    def arel_sort(collection, attr)
      conf  = sorts_configuration[attr.to_sym]
      klass = conf.fetch(:class_name, collection.klass)
      field = conf.fetch(:as, attr).to_s

      return unless klass.attribute_names.include?(field)

      klass.arel_table[field].send(SORT_ORDER[sort_sign_for(attr)])
    end

    def sort_sign_for(attr)
      attr =~ /\A[+-]/ ? attr.slice!(0) : '+'
    end

    def clean_params(params)
      params
        .split(',')
        .select { |e| sorts_configuration.keys.map(&:to_s).include?(e) }
    end
  end
end
