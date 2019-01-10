# frozen_string_literal: true

module FetcheableOnApi
  # Default configuration
  class Configuration
    attr_accessor :pagination_default_size

    def initialize
      @pagination_default_size = 25
    end
  end
end
