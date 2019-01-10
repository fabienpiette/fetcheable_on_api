# frozen_string_literal: true

module FetcheableOnApi
  # Application of a pagination on a collection
  module Pagineable
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
      response.headers['Pagination-Current-Page'] = page
      response.headers['Pagination-Per']          = limit
      response.headers['Pagination-Total-Pages']  = 1 + (count / limit).ceil
      response.headers['Pagination-Total-Count']  = count
    end

    def extract_pagination_informations(collection)
      limit = params[:page].fetch(
        :size, FetcheableOnApi.configuration.pagination_default_size
      ).to_i

      page   = params[:page].fetch(:number, 1).to_i
      offset = (page - 1) * limit
      count  = collection.except(:offset, :limit, :order).count

      [limit, offset, count, page]
    end
  end
end
