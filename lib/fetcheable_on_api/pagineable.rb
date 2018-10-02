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

      limit = params[:page].fetch(
        :size,
        FetcheableOnApi.configuration.pagination_default_size
      ).to_i

      offset = (params[:page].fetch(:number, 1).to_i - 1) * limit

      collection.limit(limit).offset(offset)
    end
  end
end
