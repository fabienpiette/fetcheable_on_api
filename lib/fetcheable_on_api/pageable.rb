# frozen_string_literal: true

module FetcheableOnApi
  # Pageable implements support for JSONAPI-compliant pagination via `page` query parameters.
  #
  # This module enables controllers to process pagination parameters in the format:
  # `page[number]=2&page[size]=25` following the JSONAPI specification for page-based pagination.
  #
  # It handles the controller parameters:
  # - `page[number]` - The requested page number (default: 1)
  # - `page[size]` - Number of records per page (default: from configuration)
  #
  # If no `page` parameter is present on the request, the full collection is returned.
  #
  # The following pagination information is automatically added to response headers:
  # - `Pagination-Current-Page` - The page number that is returned
  # - `Pagination-Per` - The number of records included in the page
  # - `Pagination-Total-Pages` - The total number of pages available
  # - `Pagination-Total-Count` - The total number of records available
  #
  # @example Basic pagination setup
  #   class UsersController < ApplicationController
  #     def index
  #       users = apply_fetcheable(User.all)
  #       render json: users
  #       # Response headers will include pagination info
  #     end
  #   end
  #
  #   # GET /users?page[number]=2&page[size]=10
  #
  # @example With custom default page size
  #   # In config/initializers/fetcheable_on_api.rb
  #   FetcheableOnApi.configure do |config|
  #     config.pagination_default_size = 50
  #   end
  #
  # @example Response headers
  #   # Pagination-Current-Page: 2
  #   # Pagination-Per: 10
  #   # Pagination-Total-Pages: 15
  #   # Pagination-Total-Count: 150
  #
  # @see https://jsonapi.org/format/#fetching-pagination JSONAPI Pagination Specification
  module Pageable
    # Protected instance methods for pagination functionality

    protected

    # Apply pagination to the collection based on page query parameters.
    # This is the main method that processes page parameters and applies
    # limit/offset to the ActiveRecord relation while setting response headers.
    #
    # @param collection [ActiveRecord::Relation] The collection to paginate
    # @return [ActiveRecord::Relation] The paginated collection with limit and offset applied
    # @raise [FetcheableOnApi::ArgumentError] When page parameters are invalid
    #
    # @example
    #   # With params: { page: { number: 2, size: 10 } }
    #   paginated_users = apply_pagination(User.all)
    #   # Generates: LIMIT 10 OFFSET 10
    #   # Sets headers: Pagination-Current-Page: 2, Pagination-Per: 10, etc.
    def apply_pagination(collection)
      # Return early if no pagination parameters are provided
      return collection if params[:page].blank?

      # Validate that page parameters are properly formatted
      foa_valid_parameters!(:page)

      # Extract pagination values and count total records
      limit, offset, count, page = extract_pagination_informations(collection)

      # Set pagination headers for the response
      define_header_pagination(limit, count, page)

      # Apply limit and offset to the collection
      collection.limit(limit).offset(offset)
    end

    private

    # Set pagination information in the response headers.
    # These headers provide clients with information about the current page
    # and total number of records/pages available.
    #
    # @param limit [Integer] Number of records per page
    # @param count [Integer] Total number of records
    # @param page [Integer] Current page number
    # @private
    def define_header_pagination(limit, count, page)
      response.headers['Pagination-Current-Page'] = page
      response.headers['Pagination-Per'] = limit
      response.headers['Pagination-Total-Pages'] = limit > 0 ? (count.to_f / limit.to_f).ceil : 0
      response.headers['Pagination-Total-Count'] = count
    end

    # Extract and calculate pagination information from parameters and collection.
    # This method processes the page parameters and calculates the appropriate
    # limit, offset, total count, and current page number.
    #
    # @param collection [ActiveRecord::Relation] The collection to paginate
    # @return [Array<Integer>] Array containing [limit, offset, count, page]
    #
    # @example
    #   # With params: { page: { number: 3, size: 20 } }
    #   limit, offset, count, page = extract_pagination_informations(User.all)
    #   # => [20, 40, 150, 3] (20 per page, skip 40 records, 150 total, page 3)
    #
    # @private
    def extract_pagination_informations(collection)
      # Get page size from parameters or use configured default
      limit = params[:page].fetch(
        :size, FetcheableOnApi.configuration.pagination_default_size
      ).to_i

      # Get page number from parameters or default to 1
      page = params[:page].fetch(:number, 1).to_i

      # Calculate offset based on page number and size
      offset = (page - 1) * limit

      # Count total records excluding any existing pagination/ordering
      # This ensures we get the total count before any pagination is applied
      count = collection.except(:offset, :limit, :order).count

      [limit, offset, count, page]
    end
  end
end
