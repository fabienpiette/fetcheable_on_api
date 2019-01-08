# frozen_string_literal: true

module FetcheableOnApi
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

      limit = params[:page].fetch(
        :size,
        FetcheableOnApi.configuration.pagination_default_size
      ).to_i

      offset = (params[:page].fetch(:number, 1).to_i - 1) * limit
      count  = collection.except(:offset, :limit, :order).count

      response.headers['Pagination-Current-Page'] = params[:page].fetch(:number, 1)
      response.headers['Pagination-Per']          = limit
      response.headers['Pagination-Total-Pages']  = 1 + (count / limit).ceil
      response.headers['Pagination-Total-Count']  = count

      collection.limit(limit).offset(offset)
    end
  end
end
