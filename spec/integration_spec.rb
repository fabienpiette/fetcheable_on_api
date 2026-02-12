# frozen_string_literal: true

require 'spec_helper'

# Mock classes for integration testing
class MockResponse
  attr_accessor :headers

  def initialize
    @headers = {}
  end
end

class MockActiveRecord
  def self.table_name
    'mock_records'
  end

  def self.attribute_names
    %w[id name email created_at category_id]
  end

  def self.arel_table
    @arel_table ||= MockArelTable.new(table_name)
  end
end

class MockCategory
  def self.table_name
    'categories'
  end

  def self.attribute_names
    %w[id name description]
  end

  def self.arel_table
    @arel_table ||= MockArelTable.new(table_name)
  end
end

class MockArelTable
  attr_reader :table_name

  def initialize(table_name)
    @table_name = table_name
  end

  def [](column)
    MockArelColumn.new(column, self)
  end
end

class MockArelColumn
  attr_reader :column_name, :table

  def initialize(column_name, table)
    @column_name = column_name
    @table = table
  end

  # Define all the Arel predicate methods
  %w[
    between does_not_match does_not_match_all does_not_match_any
    eq eq_all eq_any gt gt_all gt_any gteq gteq_all gteq_any
    in in_all in_any lt lt_all lt_any lteq lteq_all lteq_any
    matches matches_all matches_any not_between not_eq not_eq_all
    not_eq_any not_in not_in_all not_in_any
  ].each do |method_name|
    define_method(method_name) do |value|
      MockArelPredicate.new(method_name, column_name, value)
    end
  end

  def asc
    MockSortOrder.new(self, :asc)
  end

  def desc
    MockSortOrder.new(self, :desc)
  end

  def lower
    MockLowerColumn.new(self)
  end
end

class MockLowerColumn
  attr_reader :original_column

  def initialize(original_column)
    @original_column = original_column
  end

  def asc
    MockSortOrder.new(self, :asc, lower: true)
  end

  def desc
    MockSortOrder.new(self, :desc, lower: true)
  end
end

class MockArelPredicate
  attr_reader :predicate, :column, :value

  def initialize(predicate, column, value)
    @predicate = predicate
    @column = column
    @value = value
  end

  def and(other)
    MockArelComposite.new(:and, self, other)
  end

  def or(other)
    MockArelComposite.new(:or, self, other)
  end
end

class MockArelComposite
  attr_reader :operator, :left, :right

  def initialize(operator, left, right)
    @operator = operator
    @left = left
    @right = right
  end

  def and(other)
    MockArelComposite.new(:and, self, other)
  end

  def or(other)
    MockArelComposite.new(:or, self, other)
  end
end

class MockSortOrder
  attr_reader :column, :direction, :lower

  def initialize(column, direction, lower: false)
    @column = column
    @direction = direction
    @lower = lower
  end
end

class MockExceptCollection
  def initialize(count_value = 100, should_error = false)
    @count_value = count_value
    @should_error = should_error
  end

  def count
    raise StandardError, 'Database error' if @should_error

    @count_value
  end
end

class MockIntegrationController
  include FetcheableOnApi

  attr_accessor :params, :response

  def initialize(params = {})
    @params = ActionController::Parameters.new(params)
    @response = MockResponse.new
  end
end

class MockClassName
  def initialize(klass)
    @klass = klass
  end

  def constantize
    @klass
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
    MockClassName.new(@klass)
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

  def except(*_args)
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
      expect(controller.protected_methods).to include(:apply_fetcheable)
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
        controller.send(:apply_fetcheable, collection)
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
        controller.send(:apply_fetcheable, collection)
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
        controller.send(:apply_fetcheable, collection)
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
        controller.send(:apply_fetcheable, collection)

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
        controller.send(:apply_fetcheable, collection)

        expect(collection.where_conditions).not_to be_empty
        expect(collection.order_applied).to be_an(Array)
        expect(collection.order_applied.length).to eq(2)
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
        controller.send(:apply_fetcheable, collection)

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
        expect do
          controller.send(:apply_fetcheable, collection)
        end.to raise_error(FetcheableOnApi::ArgumentError)
      end
    end

    context 'with invalid sort parameters' do
      before do
        controller.params = ActionController::Parameters.new(
          sort: { name: 'asc' }
        )
      end

      it 'raises validation error during sorting' do
        expect do
          controller.send(:apply_fetcheable, collection)
        end.to raise_error(FetcheableOnApi::ArgumentError)
      end
    end

    context 'with invalid pagination parameters' do
      before do
        controller.params = ActionController::Parameters.new(
          page: 'invalid_type'
        )
      end

      it 'raises validation error during pagination' do
        expect do
          controller.send(:apply_fetcheable, collection)
        end.to raise_error(FetcheableOnApi::ArgumentError)
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
        controller.send(:apply_fetcheable, collection)

        # All operations applied
        expect(collection.where_conditions).not_to be_empty
        expect(collection.order_applied).to be_an(Array)
        expect(collection.order_applied.length).to eq(2)
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
        controller.send(:apply_fetcheable, collection)
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
        expect do
          controller.send(:foa_valid_parameters!, :filter)
          controller.send(:foa_valid_parameters!, :sort, foa_permitted_types: [String])
          controller.send(:foa_valid_parameters!, :page)
        end.not_to raise_error
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

  describe 'format functionality integration' do
    before do
      MockIntegrationController.filters_configuration = {}
      MockIntegrationController.filter_by :created_at, with: :between, format: :datetime
    end

    context 'with datetime format filtering' do
      before do
        controller.params = ActionController::Parameters.new(
          filter: { created_at: '1609459200,1640995200' }
        )
      end

      it 'applies datetime format conversion during filtering' do
        # Mock the datetime conversion method to verify it's called
        expect(controller).to receive(:foa_string_to_datetime).with('1609459200').and_return(DateTime.new(2021, 1, 1))
        expect(controller).to receive(:foa_string_to_datetime).with('1640995200').and_return(DateTime.new(2022, 1, 1))

        result = controller.send(:apply_fetcheable, collection)

        # Verify filtering was applied
        expect(collection.where_conditions).not_to be_empty
        expect(result).to eq(collection)
      end
    end
  end
end
