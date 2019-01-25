# frozen_string_literal: true

module FetcheableOnApi
  # FetcheableOnApi configuration object.
  #
  class Configuration
    # @attribute [Integer] Default pagination size
    attr_accessor :pagination_default_size

    def initialize
      @pagination_default_size = 25
    end
  end
end
