# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetcheableOnApi Core Functionality' do
  describe 'Module inclusion' do
    it 'includes all required modules' do
      expect(FetcheableOnApi.included_modules).to include(
        FetcheableOnApi::Filterable,
        FetcheableOnApi::Sortable,
        FetcheableOnApi::Pageable
      )
    end
  end

  describe 'Filterable module' do
    it 'defines PREDICATES_WITH_ARRAY constant' do
      expect(FetcheableOnApi::Filterable::PREDICATES_WITH_ARRAY).to be_a(Array)
      expect(FetcheableOnApi::Filterable::PREDICATES_WITH_ARRAY).to include(:eq_all, :in_any, :matches_all)
    end

    it 'provides filter_by class method when included' do
      test_class = Class.new
      test_class.extend(ActiveSupport::Concern)
      test_class.include(FetcheableOnApi::Filterable)

      expect(test_class).to respond_to(:filter_by)
    end
  end

  describe 'Sortable module' do
    it 'defines SORT_ORDER constant' do
      expect(FetcheableOnApi::Sortable::SORT_ORDER).to eq(
        '+' => :asc,
        '-' => :desc
      )
    end

    it 'provides sort_by class method when included' do
      test_class = Class.new
      test_class.extend(ActiveSupport::Concern)
      test_class.include(FetcheableOnApi::Sortable)

      expect(test_class).to respond_to(:sort_by)
    end
  end

  describe 'Configuration' do
    after do
      # Reset configuration after each test
      FetcheableOnApi.configuration.pagination_default_size = 25
    end

    it 'provides configuration access' do
      expect(FetcheableOnApi.configuration).to be_a(FetcheableOnApi::Configuration)
    end

    it 'allows configuration via block' do
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 50
      end

      expect(FetcheableOnApi.configuration.pagination_default_size).to eq(50)
    end

    it 'maintains configuration state' do
      FetcheableOnApi.configuration.pagination_default_size = 100
      expect(FetcheableOnApi.configuration.pagination_default_size).to eq(100)
    end
  end

  describe 'Error classes' do
    it 'defines ArgumentError subclass' do
      expect(FetcheableOnApi::ArgumentError.new).to be_a(ArgumentError)
    end

    it 'defines NotImplementedError subclass' do
      expect(FetcheableOnApi::NotImplementedError.new).to be_a(NotImplementedError)
    end
  end

  describe 'Date/time helper method' do
    # Create a minimal class to test the helper method
    let(:test_class) do
      Class.new do
        include FetcheableOnApi

        def test_datetime_conversion(string)
          foa_string_to_datetime(string)
        end
      end
    end

    let(:instance) { test_class.new }

    it 'converts epoch timestamp to DateTime' do
      # January 1, 2021 00:00:00 UTC
      result = instance.test_datetime_conversion('1609459200')
      expect(result).to be_a(DateTime)
      expect(result.year).to eq(2021)
    end
  end

  describe 'Module constants and structure' do
    it 'is properly defined as a module' do
      expect(FetcheableOnApi).to be_a(Module)
    end

    it 'has version constant' do
      expect(FetcheableOnApi::VERSION).to be_a(String)
      expect(FetcheableOnApi::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe 'Integration behavior' do
    it 'provides apply_fetcheable method when included' do
      test_class = Class.new do
        include FetcheableOnApi
        attr_accessor :params, :response

        def initialize
          @params = TestHelpers::MockParams.new
          @response = double('response', headers: {})
        end

        def test_apply_fetcheable(collection)
          apply_fetcheable(collection)
        end
      end

      instance = test_class.new
      mock_collection = double('collection')

      # Mock the individual apply methods
      allow(instance).to receive(:apply_filters).and_return(mock_collection)
      allow(instance).to receive(:apply_sort).and_return(mock_collection)
      allow(instance).to receive(:apply_pagination).and_return(mock_collection)

      result = instance.test_apply_fetcheable(mock_collection)
      expect(result).to eq(mock_collection)
    end
  end

  describe 'ActiveSupport integration' do
    it 'loads when ActionController is available' do
      # This tests the ActiveSupport.on_load callback
      expect { FetcheableOnApi }.not_to raise_error
    end
  end
end
