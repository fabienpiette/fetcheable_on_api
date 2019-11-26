# frozen_string_literal: true

module FetcheableOnApi
  # Pageable implements pagination support.
  #
  # It handles the controller parameters:
  #
  # - <code>page[:number]</code> the requested page (default: 1).
  # - <code>page[:size]</code> number of records per page.
  #
  # If no <code>page</code> parameter is present on the request, the full collection is
  # returned.
  #
  # The following pagination information is add to the response headers:
  #
  # - <code>Pagination-Current-Page</code> the page that is returned.
  # - <code>Pagination-Per</code> the number of records included in the page.
  # - <code>Pagination-Total-Pages</code> the total number of pages available.
  # - <code>Pagination-Total-Count</code> the total number of records available.
  #
  module Pageable
    #
    # Supports
    #

    #
    # Public class methods
    #

    #
    # Public instance methods
    #

    #
    # Protected instance methods
    #
    protected

    def apply_pagination(collection)
      return collection if params[:page].blank?

      foa_valid_parameters!(:page)

      limit, offset, count, page = extract_pagination_informations(collection)
      define_header_pagination(limit, count, page)

      collection.limit(limit).offset(offset)
    end

    private

    def define_header_pagination(limit, count, page)
      response.headers["Pagination-Current-Page"] = page
      response.headers["Pagination-Per"] = limit
      response.headers["Pagination-Total-Pages"] = (count.to_f / limit.to_f).ceil
      response.headers["Pagination-Total-Count"] = count
    end

    def extract_pagination_informations(collection)
      limit = params[:page].fetch(
        :size, FetcheableOnApi.configuration.pagination_default_size
      ).to_i

      page = params[:page].fetch(:number, 1).to_i
      offset = (page - 1) * limit
      count = collection.except(:offset, :limit, :order).count

      [limit, offset, count, page]
    end
  end
end
