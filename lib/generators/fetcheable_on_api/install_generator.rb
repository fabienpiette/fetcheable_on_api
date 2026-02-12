# frozen_string_literal: true

module FetcheableOnApi
  module Generators
    # Rails generator for creating FetcheableOnApi initializer file.
    #
    # This generator creates a configuration initializer file that allows
    # developers to customize FetcheableOnApi settings for their application.
    #
    # @example Running the generator
    #   rails generate fetcheable_on_api:install
    #   # Creates: config/initializers/fetcheable_on_api.rb
    #
    # @since 0.1.0
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __dir__)
      desc 'Creates FetcheableOnApi initializer for your application'

      # Copy the initializer template to the Rails application's config/initializers directory.
      # The generated file contains configuration options with sensible defaults and
      # documentation about available settings.
      #
      # @return [void]
      def copy_initializer
        template 'fetcheable_on_api_initializer.rb',
                 'config/initializers/fetcheable_on_api.rb'
      end
    end
  end
end
