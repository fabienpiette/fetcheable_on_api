# frozen_string_literal: true

module FetcheableOnApi
  # Sortable implements support for JSONAPI-compliant sorting via `sort` query parameters.
  #
  # This module enables controllers to process sort parameters in the format:
  # `sort=field1,-field2,+field3` where:
  # - No prefix or `+` prefix means ascending order
  # - `-` prefix means descending order
  # - Multiple fields are comma-separated and applied in order
  #
  # It supports:
  # - Single and multiple field sorting
  # - Ascending and descending sort directions
  # - Association sorting with custom class names
  # - Case-insensitive sorting with the `lower` option
  # - Field aliasing for different database column names
  #
  # @example Basic sorting setup
  #   class UsersController < ApplicationController
  #     sort_by :name, :email, :created_at
  #
  #     def index
  #       users = apply_fetcheable(User.all)
  #       render json: users
  #     end
  #   end
  #
  #   # GET /users?sort=name,-created_at (name asc, created_at desc)
  #
  # @example Association sorting
  #   class PostsController < ApplicationController
  #     sort_by :title, :created_at
  #     sort_by :author, class_name: User, as: 'name'
  #
  #     def index
  #       posts = apply_fetcheable(Post.joins(:author))
  #       render json: posts
  #     end
  #   end
  #
  #   # GET /posts?sort=author,-created_at (by author name asc, then created_at desc)
  #
  # @example Case-insensitive sorting
  #   class UsersController < ApplicationController
  #     sort_by :name, lower: true  # Sort by lowercase name
  #     sort_by :email, :created_at
  #
  #     def index
  #       users = apply_fetcheable(User.all)
  #       render json: users
  #     end
  #   end
  #
  #   # GET /users?sort=name (sorts by LOWER(users.name))
  #
  # @see https://jsonapi.org/format/#fetching-sorting JSONAPI Sorting Specification
  module Sortable
    # Maps sort direction prefixes to Arel sort methods.
    # Used to parse the sort parameter and determine ascending vs descending order.
    #
    # @example
    #   # "+name" or "name" -> :asc (ascending)
    #   # "-name" -> :desc (descending)
    SORT_ORDER = {
      '+' => :asc,   # Explicit ascending (same as no prefix)
      '-' => :desc,  # Explicit descending
    }.freeze

    # Hook called when Sortable is included in a class.
    # Sets up the class to support sort configuration and provides
    # the sort_by class method.
    #
    # @param base [Class] The class including this module
    # @private
    def self.included(base)
      base.class_eval do
        extend ClassMethods
        # Store sort configurations per class to avoid conflicts between controllers
        class_attribute :sorts_configuration, instance_writer: false
        self.sorts_configuration = {}
      end
    end

    # Class methods made available to controllers when Sortable is included.
    module ClassMethods
      # Define one or more sortable attributes for the controller.
      #
      # This method configures which model attributes can be sorted via query parameters
      # and how those sorts should be processed.
      #
      # @param attrs [Array<Symbol>] List of attribute names to make sortable
      # @param options [Hash] Configuration options for the sorts
      # @option options [String, Symbol] :as Alias for the database column name
      # @option options [Boolean] :lower Whether to sort on the lowercase version of the attribute
      # @option options [Class] :class_name Model class for association sorting (defaults to collection class)
      # @option options [Symbol] :association Association name when different from inferred name
      #
      # @example Basic attribute sorting
      #   sort_by :name, :email, :created_at
      #   # Allows: sort=name,-email,created_at
      #
      # @example Case-insensitive sorting
      #   sort_by :name, lower: true
      #   # Generates: ORDER BY LOWER(users.name)
      #
      # @example Association sorting
      #   sort_by :author, class_name: User, as: 'name'
      #   # Allows: sort=author (sorts by users.name)
      #
      # @example Association sorting with custom association name
      #   sort_by :author_name, class_name: User, as: 'name', association: :author
      #   # Allows: sort=author_name (sorts by users.name via author association)
      #   # Note: Make sure your collection is joined: Book.joins(:author)
      #
      # @example Field aliasing
      #   sort_by :full_name, as: 'name'
      #   # Maps sort=full_name to ORDER BY users.name
      def sort_by(*attrs)
        options = attrs.extract_options!
        options.symbolize_keys!

        # Validate that only supported options are provided
        options.assert_valid_keys(:as, :class_name, :lower, :association)

        # Create a new configuration hash to avoid modifying parent class config
        self.sorts_configuration = sorts_configuration.dup

        attrs.each do |attr|
          # Initialize default configuration for this attribute
          sorts_configuration[attr] ||= {
            as: attr
          }

          # Merge in the provided options, overriding defaults
          sorts_configuration[attr] = sorts_configuration[attr].merge(options)
        end
      end
    end

    # Protected instance methods for sorting functionality

    protected

    # Apply sorting to the collection based on sort query parameters.
    # This is the main method that processes the sort parameter and
    # applies ordering to the ActiveRecord relation.
    #
    # @param collection [ActiveRecord::Relation] The collection to sort
    # @return [ActiveRecord::Relation] The sorted collection
    # @raise [FetcheableOnApi::ArgumentError] When sort parameters are invalid
    #
    # @example
    #   # With params: { sort: 'name,-created_at' }
    #   sorted_users = apply_sort(User.all)
    #   # Generates: ORDER BY users.name ASC, users.created_at DESC
    def apply_sort(collection)
      # Return early if no sort parameters are provided
      return collection if params[:sort].blank?

      # Validate that sort parameter is a string
      foa_valid_parameters!(:sort, foa_permitted_types: [String])

      # Parse the sort parameter and build Arel ordering expressions
      ordering = format_params(params[:sort]).map do |attr_name, sort_method|
        arel_sort(attr_name, sort_method, collection)
      end

      # Apply the ordering, filtering out any nil values (unconfigured sorts)
      collection.order(ordering.compact)
    end

    private

    # Build an Arel ordering expression for the given attribute and sort direction.
    # Returns nil if the attribute is not configured for sorting or doesn't exist on the model.
    #
    # @param attr_name [Symbol] The attribute name to sort by
    # @param sort_method [Symbol] The sort direction (:asc or :desc)
    # @param collection [ActiveRecord::Relation] The collection being sorted
    # @return [Arel::Node, nil] An Arel ordering node or nil if invalid
    # @private
    def arel_sort(attr_name, sort_method, collection)
      # Skip if this attribute is not configured for sorting
      return if sorts_configuration[attr_name].blank?

      klass = class_for(attr_name, collection)
      field = field_for(attr_name)

      # Skip if the field doesn't exist on the model
      return unless belong_to_attributes_for?(klass, field)

      # Build the Arel attribute reference using the appropriate table
      attribute = klass.arel_table[field]

      # Apply lowercase transformation if configured
      config = sorts_configuration[attr_name] || {}
      attribute = attribute.lower if config.fetch(:lower, false)

      # Apply the sort direction (asc or desc)
      attribute.send(sort_method)
    end

    # Determine the model class to use for this sort attribute.
    # Uses the configured class_name or falls back to the collection's class.
    #
    # @param attr_name [Symbol] The attribute name
    # @param collection [ActiveRecord::Relation] The collection being sorted
    # @return [Class] The model class to use
    # @private
    def class_for(attr_name, collection)
      config = sorts_configuration[attr_name] || {}
      config.fetch(:class_name, collection.klass)
    end

    # Get the database field name for this sort attribute.
    # Uses the configured alias (:as option) or the attribute name itself.
    #
    # @param attr_name [Symbol] The attribute name
    # @return [String] The database column name
    # @private
    def field_for(attr_name)
      config = sorts_configuration[attr_name] || {}
      config.fetch(:as, attr_name).to_s
    end

    # Check if the given field exists as an attribute on the model class.
    # This prevents SQL errors from trying to sort by non-existent columns.
    #
    # @param klass [Class] The model class
    # @param field [String] The field name to check
    # @return [Boolean] True if the field exists on the model
    # @private
    def belong_to_attributes_for?(klass, field)
      klass.attribute_names.include?(field)
    end

    # Parse the sort parameter string into a hash of attributes and directions.
    #
    # This method takes a comma-separated string of sort fields (with optional
    # direction prefixes) and converts it into a hash mapping field names to
    # sort directions.
    #
    # @param params [String] The sort parameter string
    # @return [Hash{Symbol => Symbol}] Hash mapping attribute names to sort directions
    #
    # @example
    #   format_params("-email,first_name,+last_name")
    #   # => { email: :desc, first_name: :asc, last_name: :asc }
    #
    #   format_params("name")
    #   # => { name: :asc }
    #
    # @private
    def format_params(params)
      result = {}

      params
        .split(',') # Split on commas to get individual fields
        .each do |attribute|
        # Extract the direction prefix (+ or -) or default to +
        sort_sign = attribute =~ /\A[+-]/ ? attribute.slice!(0) : '+'

        # Map the field name to its sort direction
        result[attribute.to_sym] = SORT_ORDER[sort_sign]
      end

      result
    end
  end
end
