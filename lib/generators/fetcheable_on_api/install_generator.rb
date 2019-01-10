module FetcheableOnApi
  module Generators
    # Create conf file
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __dir__)
      desc 'Creates FetcheableOnApi initializer for your application'

      def copy_initializer
        template 'fetcheable_on_api_initializer.rb',
                 'config/initializers/fetcheable_on_api.rb'
      end
    end
  end
end
