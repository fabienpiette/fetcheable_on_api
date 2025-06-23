# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetcheableOnApi::Configuration do
  let(:configuration) { FetcheableOnApi::Configuration.new }

  describe '#initialize' do
    it 'sets default pagination_default_size to 25' do
      expect(configuration.pagination_default_size).to eq(25)
    end
  end

  describe '#pagination_default_size' do
    it 'has a getter' do
      expect(configuration).to respond_to(:pagination_default_size)
    end

    it 'has a setter' do
      expect(configuration).to respond_to(:pagination_default_size=)
    end

    it 'can be changed' do
      configuration.pagination_default_size = 50
      expect(configuration.pagination_default_size).to eq(50)
    end

    it 'accepts integer values' do
      configuration.pagination_default_size = 100
      expect(configuration.pagination_default_size).to eq(100)
    end

    it 'accepts string values that can be converted to integers' do
      configuration.pagination_default_size = '75'
      expect(configuration.pagination_default_size).to eq('75')
    end
  end

  describe 'attribute accessibility' do
    it 'allows reading pagination_default_size' do
      expect { configuration.pagination_default_size }.not_to raise_error
    end

    it 'allows writing pagination_default_size' do
      expect { configuration.pagination_default_size = 30 }.not_to raise_error
      expect(configuration.pagination_default_size).to eq(30)
    end
  end

  describe 'edge cases' do
    it 'handles zero value' do
      configuration.pagination_default_size = 0
      expect(configuration.pagination_default_size).to eq(0)
    end

    it 'handles negative values' do
      configuration.pagination_default_size = -10
      expect(configuration.pagination_default_size).to eq(-10)
    end

    it 'handles very large values' do
      large_value = 999_999_999
      configuration.pagination_default_size = large_value
      expect(configuration.pagination_default_size).to eq(large_value)
    end

    it 'handles nil value' do
      configuration.pagination_default_size = nil
      expect(configuration.pagination_default_size).to be_nil
    end
  end
end

RSpec.describe 'FetcheableOnApi Configuration Integration' do
  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(FetcheableOnApi.configuration).to be_a(FetcheableOnApi::Configuration)
    end

    it 'returns the same instance on multiple calls (singleton pattern)' do
      config1 = FetcheableOnApi.configuration
      config2 = FetcheableOnApi.configuration
      expect(config1).to be(config2)
    end

    it 'persists changes across calls' do
      FetcheableOnApi.configuration.pagination_default_size = 42
      expect(FetcheableOnApi.configuration.pagination_default_size).to eq(42)
    end
  end

  describe '.configure' do
    after do
      # Reset to default after each test
      FetcheableOnApi.configuration.pagination_default_size = 25
    end

    it 'yields the configuration instance' do
      expect { |b| FetcheableOnApi.configure(&b) }.to yield_with_args(FetcheableOnApi.configuration)
    end

    it 'allows configuration via block' do
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 15
      end
      
      expect(FetcheableOnApi.configuration.pagination_default_size).to eq(15)
    end

    it 'can be called multiple times' do
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 20
      end
      
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 30
      end
      
      expect(FetcheableOnApi.configuration.pagination_default_size).to eq(30)
    end

    it 'maintains configuration state between configure calls' do
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 35
      end
      
      # Check that the value persists
      expect(FetcheableOnApi.configuration.pagination_default_size).to eq(35)
      
      # Configure again but don't change the value
      FetcheableOnApi.configure do |config|
        # Don't modify pagination_default_size
      end
      
      # Value should still be the same
      expect(FetcheableOnApi.configuration.pagination_default_size).to eq(35)
    end
  end

  describe 'configuration usage in modules' do
    let(:controller) do
      Class.new do
        include FetcheableOnApi::Pageable
        attr_accessor :params, :response
        
        def initialize
          @params = ActionController::Parameters.new(page: { number: 1 })
          @response = double('response', headers: {})
        end
      end.new
    end

    let(:collection) do
      double('collection', 
        except: double('except_collection', count: 100),
        limit: double('limited_collection', offset: double('result'))
      )
    end

    after do
      # Reset to default after each test
      FetcheableOnApi.configuration.pagination_default_size = 25
    end

    it 'uses configuration default in pagination' do
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 40
      end

      limit, offset, count, page = controller.send(:extract_pagination_informations, collection)
      expect(limit).to eq(40)
    end

    it 'updates pagination when configuration changes' do
      # Set initial configuration
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 10
      end

      limit1, = controller.send(:extract_pagination_informations, collection)
      expect(limit1).to eq(10)

      # Change configuration
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 50
      end

      limit2, = controller.send(:extract_pagination_informations, collection)
      expect(limit2).to eq(50)
    end
  end

  describe 'thread safety' do
    after do
      # Reset to default after test
      FetcheableOnApi.configuration.pagination_default_size = 25
    end

    it 'maintains consistent configuration across threads' do
      # Set a specific value
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 60
      end

      # Create multiple threads that read the configuration
      threads = 10.times.map do
        Thread.new do
          Thread.current[:result] = FetcheableOnApi.configuration.pagination_default_size
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # All threads should see the same value
      results = threads.map { |t| t[:result] }
      expect(results).to all(eq(60))
    end
  end

  describe 'configuration persistence' do
    after do
      # Reset to default after test
      FetcheableOnApi.configuration.pagination_default_size = 25
    end

    it 'persists configuration across different access patterns' do
      # Configure using block
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 33
      end

      # Access directly
      expect(FetcheableOnApi.configuration.pagination_default_size).to eq(33)

      # Modify directly
      FetcheableOnApi.configuration.pagination_default_size = 44

      # Access via configure block
      FetcheableOnApi.configure do |config|
        expect(config.pagination_default_size).to eq(44)
      end
    end
  end

  describe 'initialization behavior' do
    it 'creates configuration lazily' do
      # Clear any existing configuration
      FetcheableOnApi.instance_variable_set(:@configuration, nil)
      
      # First access should create the configuration
      config = FetcheableOnApi.configuration
      expect(config).to be_a(FetcheableOnApi::Configuration)
      expect(config.pagination_default_size).to eq(25)
    end

    it 'does not recreate configuration on subsequent accesses' do
      config1 = FetcheableOnApi.configuration
      config1.pagination_default_size = 77
      
      config2 = FetcheableOnApi.configuration
      expect(config2.pagination_default_size).to eq(77)
      expect(config2).to be(config1)
    end
  end
end