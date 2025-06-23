# frozen_string_literal: true

module FetcheableOnApi
  # Filterable implements support for JSONAPI-compliant filtering via `filter` query parameters.
  #
  # This module enables controllers to process filter parameters in the format:
  # `filter[attribute]=value` or `filter[attribute]=value1,value2` for multiple values
  #
  # It supports:
  # - 30+ Arel predicates (eq, ilike, between, in, gt, lt, matches, etc.)
  # - Association filtering with custom class names
  # - Custom lambda predicates for complex filtering logic
  # - Multiple filter values with OR logic
  # - Date/time filtering with custom formats
  #
  # @example Basic filtering setup
  #   class UsersController < ApplicationController
  #     filter_by :name, :email, :status
  #
  #     def index
  #       users = apply_fetcheable(User.all)
  #       render json: users
  #     end
  #   end
  #
  #   # GET /users?filter[name]=john&filter[status]=active
  #
  # @example Association filtering
  #   class PostsController < ApplicationController
  #     filter_by :title
  #     filter_by :author, class_name: User, as: 'name'
  #
  #     def index
  #       posts = apply_fetcheable(Post.joins(:author))
  #       render json: posts
  #     end
  #   end
  #
  #   # GET /posts?filter[author]=john&filter[title]=rails
  #
  # @example Custom predicates
  #   class ProductsController < ApplicationController
  #     filter_by :price, with: :gteq  # Greater than or equal
  #     filter_by :created_at, with: :between, format: :datetime
  #
  #     def index
  #       products = apply_fetcheable(Product.all)
  #       render json: products
  #     end
  #   end
  #
  #   # GET /products?filter[price]=100&filter[created_at]=1609459200,1640995200
  #
  # @see https://jsonapi.org/format/#fetching-filtering JSONAPI Filtering Specification
  module Filterable
    # Arel predicates that expect array values instead of single values.
    # These predicates work with multiple values and are handled differently
    # during parameter validation and processing.
    #
    # @example Usage with array predicates
    #   filter_by :tags, with: :in_all
    #   # Expects: filter[tags][]= or filter[tags]=value1,value2
    PREDICATES_WITH_ARRAY = %i[
      does_not_match_all # None of the values should match
      does_not_match_any # At least one value should not match
      eq_all # All values must equal
      eq_any # Any value must equal
      gt_all # All values must be greater than
      gt_any # Any value must be greater than
      gteq_all # All values must be greater than or equal
      gteq_any # Any value must be greater than or equal
      in_all # Must be in all of the value sets
      in_any # Must be in any of the value sets
      lt_all # All values must be less than
      lt_any # Any value must be less than
      lteq_all # All values must be less than or equal
      lteq_any # Any value must be less than or equal
      matches_all # Must match all patterns
      matches_any # Must match any pattern
      not_eq_all # Must not equal all values
      not_eq_any # Must not equal any value
      not_in_all # Must not be in all value sets
      not_in_any # Must not be in any value set
    ].freeze

    # Hook called when Filterable is included in a class.
    # Sets up the class to support filter configuration and provides
    # the filter_by class method.
    #
    # @param base [Class] The class including this module
    # @private
    def self.included(base)
      base.class_eval do
        extend ClassMethods
        # Store filter configurations per class to avoid conflicts between controllers
        class_attribute :filters_configuration, instance_writer: false
        self.filters_configuration = {}
      end
    end

    # Class methods made available to controllers when Filterable is included.
    module ClassMethods
      # Define one or more filterable attributes for the controller.
      #
      # This method configures which model attributes can be filtered via query parameters
      # and how those filters should be processed.
      #
      # @param attrs [Array<Symbol>] List of attribute names to make filterable
      # @param options [Hash] Configuration options for the filters
      # @option options [String, Symbol] :as Alias for the database column name
      # @option options [Class] :class_name Model class for association filtering (defaults to collection class)
      # @option options [Symbol, Proc] :with Arel predicate to use (:ilike, :eq, :between, etc.) or custom lambda
      # @option options [Symbol] :format Value format (:string, :array, :datetime) for parameter processing
      # @option options [Symbol] :association Association name when different from inferred name
      #
      # @example Basic attribute filtering
      #   filter_by :name, :email, :status
      #   # Allows: filter[name]=john&filter[email]=john@example.com&filter[status]=active
      #
      # @example Custom predicate
      #   filter_by :age, with: :gteq  # Greater than or equal
      #   filter_by :created_at, with: :between, format: :datetime
      #   # Allows: filter[age]=18&filter[created_at]=1609459200,1640995200
      #
      # @example Association filtering
      #   filter_by :author, class_name: User, as: 'name'
      #   # Allows: filter[author]=john (filters by users.name)
      #
      # @example Custom lambda predicate
      #   filter_by :full_name, with: -> (collection, value) {
      #     collection.arel_table[:first_name].matches("%#{value}%").or(
      #       collection.arel_table[:last_name].matches("%#{value}%")
      #     )
      #   }
      #
      # @raise [ArgumentError] When invalid options are provided
      # @see PREDICATES_WITH_ARRAY For list of array-based predicates
      def filter_by(*attrs)
        options = attrs.extract_options!
        options.symbolize_keys!

        # Validate that only supported options are provided
        options.assert_valid_keys(:as, :class_name, :with, :format, :association)

        # Create a new configuration hash to avoid modifying parent class config
        self.filters_configuration = filters_configuration.dup

        attrs.each do |attr|
          # Initialize default configuration for this attribute
          filters_configuration[attr] ||= {
            as: options[:as] || attr
          }

          # Merge in the provided options
          filters_configuration[attr].merge!(options)
        end
      end
    end

    # Protected instance methods for filtering functionality

    protected

    # Generate the list of valid parameter keys for Rails strong parameters.
    # This method examines the filter configuration to determine which parameters
    # should be permitted, taking into account predicates that expect arrays.
    #
    # @return [Array] Array of parameter keys, with Hash format for array predicates
    # @example
    #   # For filter_by :name, :tags (where tags uses in_any predicate)
    #   # Returns: [:name, {tags: []}]
    # @private
    def valid_keys
      keys = filters_configuration.keys
      keys.each_with_index do |key, index|
        predicate = filters_configuration[key.to_sym].fetch(:with, :ilike)

        # Special handling for predicates that work with ranges or arrays
        if %i[between not_between in in_all in_any].include?(predicate)
          format = filters_configuration[key.to_sym].fetch(:format) { nil }
          # Use array format for explicit array formatting
          keys[index] = { key => [] } if format == :array
          next
        end

        # Skip if it's a custom lambda predicate or doesn't expect arrays
        next if predicate.respond_to?(:call) ||
                PREDICATES_WITH_ARRAY.exclude?(predicate.to_sym)

        # Convert to array format for predicates that expect multiple values
        keys[index] = { key => [] }
      end

      keys
    end

    # Apply filtering to the collection based on filter query parameters.
    # This is the main method that processes all configured filters and
    # applies them to the ActiveRecord relation.
    #
    # @param collection [ActiveRecord::Relation] The collection to filter
    # @return [ActiveRecord::Relation] The filtered collection
    # @raise [FetcheableOnApi::ArgumentError] When filter parameters are invalid
    #
    # @example
    #   # With params: { filter: { name: 'john', status: 'active' } }
    #   filtered_users = apply_filters(User.all)
    #   # Generates: WHERE users.name ILIKE '%john%' AND users.status ILIKE '%active%'
    def apply_filters(collection)
      # Return early if no filter parameters are provided
      return collection if params[:filter].blank?

      # Validate that filter parameters are properly formatted
      foa_valid_parameters!(:filter)

      # Extract and permit only configured filter parameters
      filter_params = params.require(:filter)
                            .permit(valid_keys)
                            .to_hash

      # Process each filter parameter and build Arel predicates
      filtering = filter_params.map do |column, values|
        config = filters_configuration[column.to_sym]

        # Extract configuration for this filter
        format = config.fetch(:format, :string)
        column_name = config.fetch(:as, column)
        klass = config.fetch(:class_name, collection.klass)
        collection_klass = collection.name.constantize
        association_class_or_name = config.fetch(
          :association, klass.table_name.to_sym
        )

        predicate = config.fetch(:with, :ilike)

        # Join association table if filtering on a different model
        if collection_klass != klass
          collection = collection.joins(association_class_or_name)
        end

        # Handle range-based predicates (between, not_between)
        if %i[between not_between].include?(predicate)
          if values.is_a?(String)
            # Single range: "start,end"
            predicates(predicate, collection, klass, column_name, values.split(','))
          else
            # Multiple ranges: ["start1,end1", "start2,end2"] with OR logic
            values.map do |value|
              predicates(predicate, collection, klass, column_name, value.split(','))
            end.inject(:or)
          end
        elsif values.is_a?(String)
          # Single value or comma-separated values with OR logic
          values.split(',').map do |value|
            predicates(predicate, collection, klass, column_name, value)
          end.inject(:or)
        else
          # Array of values, each potentially comma-separated
          values.map! { |el| el.split(',') }
          predicates(predicate, collection, klass, column_name, values)
        end
      end

      # Combine all filter predicates with AND logic
      collection.where(filtering.flatten.compact.inject(:and))
    end

    # Build an Arel predicate for the given parameters.
    # This method translates filter predicates into Arel expressions that can
    # be used in ActiveRecord where clauses.
    #
    # @param predicate [Symbol, Proc] The predicate type (:eq, :ilike, :between, etc.) or custom lambda
    # @param collection [ActiveRecord::Relation] The collection being filtered (used for lambda predicates)
    # @param klass [Class] The model class for the attribute being filtered
    # @param column_name [String, Symbol] The database column name to filter on
    # @param value [Object] The filter value(s) to compare against
    # @return [Arel::Node] An Arel predicate node
    # @raise [ArgumentError] When an unsupported predicate is used
    #
    # @example
    #   # predicates(:eq, collection, User, 'name', 'john')
    #   # Returns: users.name = 'john'
    #
    #   # predicates(:between, collection, User, 'age', [18, 65])
    #   # Returns: users.age BETWEEN 18 AND 65
    #
    # @private
    def predicates(predicate, collection, klass, column_name, value)
      case predicate
      # Range predicates - work with two values (start, end)
      when :between
        klass.arel_table[column_name].between(value.first..value.last)
      when :not_between
        klass.arel_table[column_name].not_between(value.first..value.last)

      # Equality predicates - exact matching
      when :eq
        klass.arel_table[column_name].eq(value)
      when :not_eq
        klass.arel_table[column_name].not_eq(value)

      # Comparison predicates - numeric/date comparisons
      when :gt
        klass.arel_table[column_name].gt(value)
      when :gteq
        klass.arel_table[column_name].gteq(value)
      when :lt
        klass.arel_table[column_name].lt(value)
      when :lteq
        klass.arel_table[column_name].lteq(value)

      # Array inclusion predicates - check if value is in a set
      when :in
        if value.is_a?(Array)
          klass.arel_table[column_name].in(value.flatten.compact.uniq)
        else
          klass.arel_table[column_name].in(value)
        end
      when :not_in
        klass.arel_table[column_name].not_in(value)

      # Pattern matching predicates - for text search
      when :ilike
        # Default predicate - case-insensitive partial matching
        klass.arel_table[column_name].matches("%#{value}%")
      when :matches
        # Exact pattern matching (supports SQL wildcards)
        klass.arel_table[column_name].matches(value)
      when :does_not_match
        klass.arel_table[column_name].does_not_match("%#{value}%")

      # Array-based predicates (work with multiple values)
      when :eq_all
        klass.arel_table[column_name].eq_all(value)
      when :eq_any
        klass.arel_table[column_name].eq_any(value)
      when :gt_all
        klass.arel_table[column_name].gt_all(value)
      when :gt_any
        klass.arel_table[column_name].gt_any(value)
      when :gteq_all
        klass.arel_table[column_name].gteq_all(value)
      when :gteq_any
        klass.arel_table[column_name].gteq_any(value)
      when :lt_all
        klass.arel_table[column_name].lt_all(value)
      when :lt_any
        klass.arel_table[column_name].lt_any(value)
      when :lteq_all
        klass.arel_table[column_name].lteq_all(value)
      when :lteq_any
        klass.arel_table[column_name].lteq_any(value)
      when :in_all
        if value.is_a?(Array)
          klass.arel_table[column_name].in_all(value.flatten.compact.uniq)
        else
          klass.arel_table[column_name].in_all(value)
        end
      when :in_any
        if value.is_a?(Array)
          klass.arel_table[column_name].in_any(value.flatten.compact.uniq)
        else
          klass.arel_table[column_name].in_any(value)
        end
      when :not_eq_all
        klass.arel_table[column_name].not_eq_all(value)
      when :not_eq_any
        klass.arel_table[column_name].not_eq_any(value)
      when :not_in_all
        klass.arel_table[column_name].not_in_all(value)
      when :not_in_any
        klass.arel_table[column_name].not_in_any(value)
      when :matches_all
        klass.arel_table[column_name].matches_all(value)
      when :matches_any
        klass.arel_table[column_name].matches_any(value)
      when :does_not_match_all
        klass.arel_table[column_name].does_not_match_all(value)
      when :does_not_match_any
        klass.arel_table[column_name].does_not_match_any(value)
      else
        # Handle custom lambda predicates
        unless predicate.respond_to?(:call)
          raise ArgumentError,
                "unsupported predicate `#{predicate}`"
        end

        # Call the custom predicate with collection and value
        predicate.call(collection, value)
      end
    end

    # Override the default permitted types to allow Arrays for filter parameters.
    # Filtering supports more flexible parameter types compared to sorting/pagination
    # since filter values can be arrays of values for certain predicates.
    #
    # @return [Array<Class>] Array of permitted parameter types for filtering
    # @private
    def foa_default_permitted_types
      [ActionController::Parameters, Hash, Array]
    end
  end
end
