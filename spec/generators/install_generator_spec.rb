# frozen_string_literal: true

require 'spec_helper'

# Stub Rails::Generators::Base so the generator can load without Rails
module Rails
  module Generators
    class Base
      def self.source_root(path = nil)
        @source_root = path if path
        @source_root
      end

      def self.desc(description = nil)
        @desc = description if description
        @desc
      end

      def template(*_args); end
    end
  end
end

require 'generators/fetcheable_on_api/install_generator'

RSpec.describe FetcheableOnApi::Generators::InstallGenerator do
  describe 'class configuration' do
    it 'inherits from Rails::Generators::Base' do
      expect(described_class.superclass).to eq(Rails::Generators::Base)
    end

    it 'sets source_root to the templates directory' do
      source_root = described_class.source_root
      expect(source_root).to end_with('lib/generators/templates')
    end

    it 'has a description' do
      expect(described_class.desc).to include('FetcheableOnApi')
    end
  end

  describe '#copy_initializer' do
    it 'is defined as an instance method' do
      expect(described_class.instance_methods(false)).to include(:copy_initializer)
    end

    it 'calls template with the correct arguments' do
      generator = described_class.new
      expect(generator).to receive(:template).with(
        'fetcheable_on_api_initializer.rb',
        'config/initializers/fetcheable_on_api.rb'
      )
      generator.copy_initializer
    end
  end

  describe 'template file' do
    let(:template_path) do
      File.expand_path('../../lib/generators/templates/fetcheable_on_api_initializer.rb', __dir__)
    end

    it 'exists on disk' do
      expect(File.exist?(template_path)).to be true
    end

    it 'contains configuration block' do
      content = File.read(template_path)
      expect(content).to include('FetcheableOnApi.configure')
      expect(content).to include('pagination_default_size')
    end
  end
end
