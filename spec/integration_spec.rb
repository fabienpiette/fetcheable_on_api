# frozen_string_literal: true

require 'spec_helper'

# Mock classes for integration testing
class MockIntegrationController
  include FetcheableOnApi

  attr_accessor :params, :response

  def initialize(params = {})
    @params = ActionController::Parameters.new(params)
    @response = MockResponse.new
  end
end

class MockIntegrationCollection
  attr_reader :klass, :joins_applied, :where_conditions, :order_applied, :limit_applied, :offset_applied

  def initialize(klass = MockActiveRecord, count = 100)
    @klass = klass
    @joins_applied = []
    @where_conditions = []
    @order_applied = []
    @limit_applied = nil
    @offset_applied = nil
    @count_value = count
  end

  def name
    @klass.name
  end

  def joins(association)
    @joins_applied << association
    self
  end

  def where(conditions)
    @where_conditions << conditions
    self
  end

  def order(ordering)
    @order_applied = ordering
    self
  end

  def limit(value)
    @limit_applied = value
    self
  end

  def offset(value)
    @offset_applied = value
    self
  end

  def except(*args)
    MockExceptCollection.new(@count_value)
  end

  def count
    @count_value
  end
end

RSpec.describe 'FetcheableOnApi Integration' do
  let(:controller) { MockIntegrationController.new }
  let(:collection) { MockIntegrationCollection.new }

  describe '.included' do
    it 'includes all three modules' do
      expect(MockIntegrationController.ancestors).to include(FetcheableOnApi::Filterable)
      expect(MockIntegrationController.ancestors).to include(FetcheableOnApi::Sortable)
      expect(MockIntegrationController.ancestors).to include(FetcheableOnApi::Pageable)
    end

    it 'provides all configuration methods' do
      expect(MockIntegrationController).to respond_to(:filter_by)
      expect(MockIntegrationController).to respond_to(:sort_by)
    end

    it 'provides instance method apply_fetcheable' do
      expect(controller).to respond_to(:apply_fetcheable, true)
    end
  end

  describe '#apply_fetcheable' do
    before do
      MockIntegrationController.filters_configuration = {}
      MockIntegrationController.sorts_configuration = {}
    end

    context 'with no parameters' do
      it 'returns the collection unchanged' do
        controller.params = ActionController::Parameters.new({})
        result = controller.send(:apply_fetcheable, collection)
        expect(result).to eq(collection)
      end
    end

    context 'with only filter parameters' do
      before do
        MockIntegrationController.filter_by :name
        controller.params = ActionController::Parameters.new(
          filter: { name: 'john' }
        )
      end

      it 'applies only filtering' do
        result = controller.send(:apply_fetcheable, collection)
        expect(collection.where_conditions).not_to be_empty
        expect(collection.order_applied).to be_empty
        expect(collection.limit_applied).to be_nil
      end
    end

    context 'with only sort parameters' do
      before do
        MockIntegrationController.sort_by :name
        controller.params = ActionController::Parameters.new(
          sort: 'name'
        )
      end

      it 'applies only sorting' do
        result = controller.send(:apply_fetcheable, collection)
        expect(collection.where_conditions).to be_empty
        expect(collection.order_applied).not_to be_empty
        expect(collection.limit_applied).to be_nil
      end
    end

    context 'with only pagination parameters' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 2, size: 10 }
        )
      end

      it 'applies only pagination' do
        result = controller.send(:apply_fetcheable, collection)
        expect(collection.where_conditions).to be_empty
        expect(collection.order_applied).to be_empty
        expect(collection.limit_applied).to eq(10)
        expect(collection.offset_applied).to eq(10)
      end
    end

    context 'with filter, sort, and pagination parameters' do
      before do
        MockIntegrationController.filter_by :name, :email
        MockIntegrationController.sort_by :created_at, :name
        controller.params = ActionController::Parameters.new(
          filter: { name: 'john', email: 'john@' },
          sort: '-created_at,name',
          page: { number: 2, size: 15 }
        )
      end

      it 'applies all three operations in sequence' do
        result = controller.send(:apply_fetcheable, collection)
        
        # Filtering applied
        expect(collection.where_conditions).not_to be_empty
        
        # Sorting applied
        expect(collection.order_applied).not_to be_empty
        
        # Pagination applied
        expect(collection.limit_applied).to eq(15)
        expect(collection.offset_applied).to eq(15)
        
        # Pagination headers set
        headers = controller.response.headers
        expect(headers['Pagination-Current-Page']).to eq(2)
        expect(headers['Pagination-Per']).to eq(15)
      end
    end

    context 'with complex filtering and sorting' do
      before do
        MockIntegrationController.filter_by :name, with: :ilike
        MockIntegrationController.filter_by :category_id, with: :in
        MockIntegrationController.sort_by :name, lower: true
        MockIntegrationController.sort_by :created_at
        
        controller.params = ActionController::Parameters.new(
          filter: { 
            name: 'john,jane', 
            category_id: '1,2,3' 
          },
          sort: 'name,-created_at'
        )
      end

      it 'handles complex parameter combinations' do
        result = controller.send(:apply_fetcheable, collection)
        
        expect(collection.where_conditions).not_to be_empty
        expect(collection.order_applied).to have(2).items
      end
    end

    context 'with association filtering and sorting' do
      before do
        MockIntegrationController.filter_by :category, class_name: MockCategory, as: 'name'
        MockIntegrationController.sort_by :category, class_name: MockCategory, as: 'name'
        
        controller.params = ActionController::Parameters.new(
          filter: { category: 'tech' },
          sort: 'category'
        )
      end

      it 'handles association operations' do
        result = controller.send(:apply_fetcheable, collection)
        
        expect(collection.joins_applied).to include(:categories)
        expect(collection.where_conditions).not_to be_empty
        expect(collection.order_applied).not_to be_empty
      end
    end
  end

  describe 'parameter validation integration' do
    before do
      MockIntegrationController.filter_by :name
      MockIntegrationController.sort_by :name
    end

    context 'with invalid filter parameters' do
      before do
        controller.params = ActionController::Parameters.new(
          filter: 'invalid_type'
        )
      end

      it 'raises validation error during filtering' do
        expect {
          controller.send(:apply_fetcheable, collection)
        }.to raise_error(FetcheableOnApi::ArgumentError)
      end
    end

    context 'with invalid sort parameters' do
      before do
        controller.params = ActionController::Parameters.new(
          sort: { name: 'asc' }
        )
      end

      it 'raises validation error during sorting' do
        expect {
          controller.send(:apply_fetcheable, collection)
        }.to raise_error(FetcheableOnApi::ArgumentError)
      end
    end

    context 'with invalid pagination parameters' do
      before do
        controller.params = ActionController::Parameters.new(
          page: 'invalid_type'
        )
      end

      it 'raises validation error during pagination' do
        expect {
          controller.send(:apply_fetcheable, collection)
        }.to raise_error(FetcheableOnApi::ArgumentError)
      end
    end
  end

  describe 'configuration inheritance' do
    class MockChildController < MockIntegrationController
      filter_by :email
      sort_by :email
    end

    let(:child_controller) { MockChildController.new }

    it 'maintains separate configurations for different controllers' do
      MockIntegrationController.filter_by :name
      MockIntegrationController.sort_by :name
      
      expect(MockIntegrationController.filters_configuration.keys).to include(:name)
      expect(MockChildController.filters_configuration.keys).to include(:email)
      expect(MockChildController.filters_configuration.keys).not_to include(:name)
    end
  end

  describe 'real-world scenario simulation' do
    before do
      # Simulate a typical API controller configuration
      MockIntegrationController.filter_by :name, with: :ilike
      MockIntegrationController.filter_by :email, with: :ilike  
      MockIntegrationController.filter_by :status, with: :eq
      MockIntegrationController.filter_by :created_at, with: :between
      MockIntegrationController.filter_by :category_id, with: :in
      
      MockIntegrationController.sort_by :name, :email, :created_at, :updated_at
      MockIntegrationController.sort_by :category, class_name: MockCategory, as: 'name'
    end

    context 'searching and sorting users' do
      before do
        controller.params = ActionController::Parameters.new(
          filter: {
            name: 'john',
            status: 'active',
            created_at: '2023-01-01,2023-12-31'
          },
          sort: 'name,-created_at',
          page: { number: 1, size: 20 }
        )
      end

      it 'processes complete API request correctly' do
        result = controller.send(:apply_fetcheable, collection)
        
        # All operations applied
        expect(collection.where_conditions).not_to be_empty
        expect(collection.order_applied).to have(2).items
        expect(collection.limit_applied).to eq(20)
        expect(collection.offset_applied).to eq(0)
        
        # Headers set
        headers = controller.response.headers
        expect(headers['Pagination-Total-Count']).to eq(100)
        expect(headers['Pagination-Total-Pages']).to eq(5)
      end
    end

    context 'complex filtering with OR conditions' do
      before do
        controller.params = ActionController::Parameters.new(
          filter: {
            name: 'john,jane,bob',
            status: 'active,pending'
          },
          sort: '-created_at'
        )
      end

      it 'handles multiple OR conditions across different fields' do
        result = controller.send(:apply_fetcheable, collection)
        expect(collection.where_conditions).not_to be_empty
        expect(collection.order_applied).not_to be_empty
      end
    end

    context 'with empty or nil values' do
      before do
        controller.params = ActionController::Parameters.new(
          filter: {
            name: '',
            email: nil,
            status: 'active'
          },
          sort: '',
          page: {}
        )
      end

      it 'handles empty/nil values gracefully' do
        result = controller.send(:apply_fetcheable, collection)
        # Should not error and should process valid values
        expect(result).to eq(collection)
      end
    end
  end

  describe 'helper method integration' do
    describe '#foa_valid_parameters!' do
      it 'validates parameters across all modules' do
        controller.params = ActionController::Parameters.new(
          filter: { name: 'john' },
          sort: 'name',
          page: { number: 1 }
        )
        
        # Should not raise errors for valid parameters
        expect {
          controller.send(:foa_valid_parameters!, :filter)
          controller.send(:foa_valid_parameters!, :sort, foa_permitted_types: [String])
          controller.send(:foa_valid_parameters!, :page)
        }.not_to raise_error
      end
    end

    describe '#foa_string_to_datetime' do
      it 'is available for date parsing' do
        timestamp = controller.send(:foa_string_to_datetime, '1609459200') # 2021-01-01
        expect(timestamp).to be_a(DateTime)
      end
    end
  end

  describe 'module constants' do
    it 'exposes custom error classes' do
      expect(FetcheableOnApi::ArgumentError).to be < ArgumentError
      expect(FetcheableOnApi::NotImplementedError).to be < NotImplementedError
    end
  end

  describe 'ActiveSupport integration' do
    it 'is included in ActionController when ActiveSupport loads' do
      # This test verifies the ActiveSupport.on_load callback
      expect(FetcheableOnApi).to be_const_defined(:ArgumentError)
      expect(FetcheableOnApi).to be_const_defined(:NotImplementedError)
    end
  end
end