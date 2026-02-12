# frozen_string_literal: true

require 'spec_helper'

# Mock ActiveRecord classes for testing
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

class MockCollection
  attr_reader :klass, :joins_applied, :where_conditions

  def initialize(klass = MockActiveRecord)
    @klass = klass
    @joins_applied = []
    @where_conditions = []
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
end

class MockResponse
  attr_accessor :headers

  def initialize
    @headers = {}
  end
end

class MockController
  include FetcheableOnApi

  attr_accessor :params, :response

  def initialize(params = {})
    @params = ActionController::Parameters.new(params)
    @response = MockResponse.new
  end
end

RSpec.describe FetcheableOnApi::Filterable do
  let(:controller) { MockController.new }
  let(:collection) { MockCollection.new }

  describe '.included' do
    it 'extends the class with ClassMethods' do
      expect(MockController).to respond_to(:filter_by)
    end

    it 'adds filters_configuration class attribute' do
      expect(MockController).to respond_to(:filters_configuration)
      expect(MockController.filters_configuration).to eq({})
    end
  end

  describe '.filter_by' do
    it 'configures simple filters' do
      MockController.filter_by :name, :email

      expect(MockController.filters_configuration[:name]).to eq(as: :name)
      expect(MockController.filters_configuration[:email]).to eq(as: :email)
    end

    it 'configures filters with options' do
      MockController.filter_by :name, as: 'full_name', with: :eq

      expect(MockController.filters_configuration[:name]).to include(
        as: 'full_name',
        with: :eq
      )
    end

    it 'configures filters with class_name for associations' do
      MockController.filter_by :category, class_name: MockCategory, as: 'name'

      expect(MockController.filters_configuration[:category]).to include(
        class_name: MockCategory,
        as: 'name'
      )
    end

    it 'validates allowed options' do
      expect do
        MockController.filter_by :name, invalid_option: 'value'
      end.to raise_error(ArgumentError)
    end
  end

  describe '#apply_filters' do
    before do
      MockController.filters_configuration = {}
    end

    context 'when no filter params are present' do
      it 'returns the collection unchanged' do
        controller.params = ActionController::Parameters.new({})
        result = controller.send(:apply_filters, collection)
        expect(result).to eq(collection)
      end
    end

    context 'with basic string filters' do
      before do
        MockController.filter_by :name
        controller.params = ActionController::Parameters.new(
          filter: { name: 'john' }
        )
      end

      it 'applies ilike filter by default' do
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end
    end

    context 'with multiple filter values' do
      before do
        MockController.filter_by :name
        controller.params = ActionController::Parameters.new(
          filter: { name: 'john,jane' }
        )
      end

      it 'splits comma-separated values and applies OR logic' do
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end
    end

    context 'with eq predicate' do
      before do
        MockController.filter_by :name, with: :eq
        controller.params = ActionController::Parameters.new(
          filter: { name: 'john' }
        )
      end

      it 'applies exact match filter' do
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end
    end

    context 'with between predicate' do
      before do
        MockController.filter_by :created_at, with: :between
        controller.params = ActionController::Parameters.new(
          filter: { created_at: '2023-01-01,2023-12-31' }
        )
      end

      it 'applies between filter with date range' do
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end
    end

    context 'with in predicate' do
      before do
        MockController.filter_by :category_id, with: :in
        controller.params = ActionController::Parameters.new(
          filter: { category_id: '1,2,3' }
        )
      end

      it 'applies in filter with multiple values' do
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end
    end

    context 'with association filters' do
      before do
        MockController.filter_by :category, class_name: MockCategory, as: 'name'
        controller.params = ActionController::Parameters.new(
          filter: { category: 'tech' }
        )
      end

      it 'joins the association and applies filter' do
        result = controller.send(:apply_filters, collection)
        expect(collection.joins_applied).to include(:categories)
        expect(collection.where_conditions).not_to be_empty
      end
    end

    context 'with lambda predicate' do
      let(:custom_predicate) do
        lambda do |_collection, value|
          MockArelPredicate.new('custom', 'name', value)
        end
      end

      before do
        MockController.filter_by :name, with: custom_predicate
        controller.params = ActionController::Parameters.new(
          filter: { name: 'test' }
        )
      end

      it 'applies custom lambda predicate' do
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end
    end
  end

  describe '#predicates' do
    let(:klass) { MockActiveRecord }
    let(:column_name) { 'name' }

    it 'handles between predicate' do
      result = controller.send(:predicates, :between, collection, klass, column_name, ['2023-01-01', '2023-12-31'])
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('between')
    end

    it 'handles eq predicate' do
      result = controller.send(:predicates, :eq, collection, klass, column_name, 'john')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('eq')
      expect(result.value).to eq('john')
    end

    it 'handles ilike predicate' do
      result = controller.send(:predicates, :ilike, collection, klass, column_name, 'john')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('matches')
    end

    it 'handles in predicate with arrays' do
      result = controller.send(:predicates, :in, collection, klass, column_name, %w[1 2 3])
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('in')
    end

    it 'handles gt predicate' do
      result = controller.send(:predicates, :gt, collection, klass, column_name, '100')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('gt')
    end

    it 'handles lt predicate' do
      result = controller.send(:predicates, :lt, collection, klass, column_name, '100')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('lt')
    end

    it 'handles not_eq predicate' do
      result = controller.send(:predicates, :not_eq, collection, klass, column_name, 'john')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('not_eq')
    end

    it 'handles custom lambda predicates' do
      custom_predicate = ->(_coll, val) { MockArelPredicate.new('custom', 'name', val) }
      result = controller.send(:predicates, custom_predicate, collection, klass, column_name, 'test')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('custom')
    end

    it 'handles not_between predicate' do
      result = controller.send(:predicates, :not_between, collection, klass, column_name, ['2023-01-01', '2023-12-31'])
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('not_between')
    end

    it 'handles gteq predicate' do
      result = controller.send(:predicates, :gteq, collection, klass, column_name, '100')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('gteq')
      expect(result.value).to eq('100')
    end

    it 'handles lteq predicate' do
      result = controller.send(:predicates, :lteq, collection, klass, column_name, '100')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('lteq')
      expect(result.value).to eq('100')
    end

    it 'handles not_in predicate' do
      result = controller.send(:predicates, :not_in, collection, klass, column_name, %w[a b])
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('not_in')
    end

    it 'handles matches predicate' do
      result = controller.send(:predicates, :matches, collection, klass, column_name, '%john%')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('matches')
      expect(result.value).to eq('%john%')
    end

    it 'handles does_not_match predicate' do
      result = controller.send(:predicates, :does_not_match, collection, klass, column_name, 'john')
      expect(result).to be_a(MockArelPredicate)
      expect(result.predicate).to eq('does_not_match')
      expect(result.value).to eq('%john%')
    end

    context 'with array predicates' do
      {
        eq_all: %w[a b],
        eq_any: %w[a b],
        gt_all: %w[1 2],
        gt_any: %w[1 2],
        gteq_all: %w[1 2],
        gteq_any: %w[1 2],
        lt_all: %w[1 2],
        lt_any: %w[1 2],
        lteq_all: %w[1 2],
        lteq_any: %w[1 2],
        not_eq_all: %w[a b],
        not_eq_any: %w[a b],
        not_in_all: %w[a b],
        not_in_any: %w[a b],
        matches_all: %w[%a% %b%],
        matches_any: %w[%a% %b%],
        does_not_match_all: %w[%a% %b%],
        does_not_match_any: %w[%a% %b%],
      }.each do |pred, test_value|
        it "handles #{pred} predicate" do
          result = controller.send(:predicates, pred, collection, klass, column_name, test_value)
          expect(result).to be_a(MockArelPredicate)
          expect(result.predicate).to eq(pred.to_s)
          expect(result.value).to eq(test_value)
        end
      end
    end

    context 'with :in array branch' do
      it 'handles :in with Array input (flatten/compact/uniq)' do
        result = controller.send(:predicates, :in, collection, klass, column_name, [%w[1 2], nil, '1'])
        expect(result).to be_a(MockArelPredicate)
        expect(result.predicate).to eq('in')
        expect(result.value).to eq(%w[1 2])
      end

      it 'handles :in with non-Array input' do
        result = controller.send(:predicates, :in, collection, klass, column_name, '42')
        expect(result).to be_a(MockArelPredicate)
        expect(result.predicate).to eq('in')
        expect(result.value).to eq('42')
      end
    end

    context 'with :in_all array branch' do
      it 'handles :in_all with Array input (flatten/compact/uniq)' do
        result = controller.send(:predicates, :in_all, collection, klass, column_name, [%w[a b], nil, 'a'])
        expect(result).to be_a(MockArelPredicate)
        expect(result.predicate).to eq('in_all')
        expect(result.value).to eq(%w[a b])
      end

      it 'handles :in_all with non-Array input' do
        result = controller.send(:predicates, :in_all, collection, klass, column_name, '42')
        expect(result).to be_a(MockArelPredicate)
        expect(result.predicate).to eq('in_all')
        expect(result.value).to eq('42')
      end
    end

    context 'with :in_any array branch' do
      it 'handles :in_any with Array input (flatten/compact/uniq)' do
        result = controller.send(:predicates, :in_any, collection, klass, column_name, [%w[x y], nil, 'x'])
        expect(result).to be_a(MockArelPredicate)
        expect(result.predicate).to eq('in_any')
        expect(result.value).to eq(%w[x y])
      end

      it 'handles :in_any with non-Array input' do
        result = controller.send(:predicates, :in_any, collection, klass, column_name, '42')
        expect(result).to be_a(MockArelPredicate)
        expect(result.predicate).to eq('in_any')
        expect(result.value).to eq('42')
      end
    end

    it 'raises error for unsupported predicates' do
      expect do
        controller.send(:predicates, :unsupported, collection, klass, column_name, 'value')
      end.to raise_error(ArgumentError, /unsupported predicate/)
    end
  end

  describe '#valid_keys' do
    context 'with simple filters' do
      before do
        MockController.filter_by :name, :email
      end

      it 'returns array of filter keys' do
        keys = controller.send(:valid_keys)
        expect(keys).to include(:name, :email)
      end
    end

    context 'with array predicates' do
      before do
        MockController.filter_by :tags, with: :in_all
      end

      it 'returns hash format for array predicates' do
        keys = controller.send(:valid_keys)
        expect(keys).to include(tags: [])
      end
    end

    context 'with between predicates' do
      before do
        MockController.filter_by :date_range, with: :between, format: :array
      end

      it 'returns hash format for between with array format' do
        keys = controller.send(:valid_keys)
        expect(keys).to include(date_range: [])
      end
    end

    context 'with :in predicate without :array format' do
      before do
        MockController.filters_configuration = {}
        MockController.filter_by :category_id, with: :in
      end

      it 'returns plain key (no hash format)' do
        keys = controller.send(:valid_keys)
        expect(keys).to include(:category_id)
        expect(keys).not_to include(category_id: [])
      end
    end

    context 'with :in predicate with format: :array' do
      before do
        MockController.filters_configuration = {}
        MockController.filter_by :category_id, with: :in, format: :array
      end

      it 'returns hash format for array' do
        keys = controller.send(:valid_keys)
        expect(keys).to include(category_id: [])
      end
    end

    context 'with :not_between predicate' do
      before do
        MockController.filters_configuration = {}
        MockController.filter_by :date_range, with: :not_between
      end

      it 'returns plain key without array format' do
        keys = controller.send(:valid_keys)
        expect(keys).to include(:date_range)
      end
    end

    context 'with lambda predicate' do
      before do
        MockController.filters_configuration = {}
        MockController.filter_by :custom, with: ->(_c, v) { v }
      end

      it 'returns plain key (lambda skips array conversion)' do
        keys = controller.send(:valid_keys)
        expect(keys).to include(:custom)
        expect(keys).not_to include(custom: [])
      end
    end

    context 'with PREDICATES_WITH_ARRAY outside between/in group (e.g., :eq_any)' do
      before do
        MockController.filters_configuration = {}
        MockController.filter_by :tags, with: :eq_any
      end

      it 'returns hash format for array predicates' do
        keys = controller.send(:valid_keys)
        expect(keys).to include(tags: [])
      end
    end
  end

  describe 'PREDICATES_WITH_ARRAY constant' do
    it 'includes all array-based predicates' do
      expected_predicates = %i[
        does_not_match_all does_not_match_any eq_all eq_any
        gt_all gt_any gteq_all gteq_any in_all in_any
        lt_all lt_any lteq_all lteq_any matches_all matches_any
        not_eq_all not_eq_any not_in_all not_in_any
      ]

      expect(FetcheableOnApi::Filterable::PREDICATES_WITH_ARRAY).to match_array(expected_predicates)
    end
  end

  describe 'parameter validation' do
    before do
      MockController.filter_by :name
    end

    it 'validates filter parameter types' do
      controller.params = ActionController::Parameters.new(filter: 'invalid')

      expect do
        controller.send(:apply_filters, collection)
      end.to raise_error(FetcheableOnApi::ArgumentError)
    end

    it 'accepts valid parameter types' do
      controller.params = ActionController::Parameters.new(filter: { name: 'john' })

      expect do
        controller.send(:apply_filters, collection)
      end.not_to raise_error
    end
  end

  describe 'edge cases' do
    before do
      MockController.filter_by :name
    end

    it 'handles empty filter values' do
      controller.params = ActionController::Parameters.new(filter: { name: '' })
      result = controller.send(:apply_filters, collection)
      expect(result).to eq(collection)
    end

    it 'handles nil filter values' do
      controller.params = ActionController::Parameters.new(filter: { name: nil })
      result = controller.send(:apply_filters, collection)
      expect(result).to eq(collection)
    end
  end

  describe 'format functionality' do
    describe 'datetime format' do
      before do
        MockController.filters_configuration = {}
        MockController.filter_by :created_at, with: :eq, format: :datetime
      end

      it 'converts string timestamps to DateTime objects for single values' do
        controller.params = ActionController::Parameters.new(filter: { created_at: '1609459200' })
        
        expect(controller).to receive(:foa_string_to_datetime).with('1609459200').and_return(DateTime.new(2021, 1, 1))
        
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end

      it 'converts comma-separated timestamps for multiple values' do
        controller.params = ActionController::Parameters.new(filter: { created_at: '1609459200,1640995200' })
        
        expect(controller).to receive(:foa_string_to_datetime).with('1609459200').and_return(DateTime.new(2021, 1, 1))
        expect(controller).to receive(:foa_string_to_datetime).with('1640995200').and_return(DateTime.new(2022, 1, 1))
        
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end

      it 'converts array of timestamps' do
        controller.params = ActionController::Parameters.new(filter: { created_at: ['1609459200', '1640995200'] })
        
        expect(controller).to receive(:foa_string_to_datetime).with('1609459200').and_return(DateTime.new(2021, 1, 1))
        expect(controller).to receive(:foa_string_to_datetime).with('1640995200').and_return(DateTime.new(2022, 1, 1))
        
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end

      context 'with between predicate' do
        before do
          MockController.filters_configuration = {}
          MockController.filter_by :created_at, with: :between, format: :datetime
        end

        it 'converts range timestamps for between predicate' do
          controller.params = ActionController::Parameters.new(filter: { created_at: '1609459200,1640995200' })
          
          expect(controller).to receive(:foa_string_to_datetime).with('1609459200').and_return(DateTime.new(2021, 1, 1))
          expect(controller).to receive(:foa_string_to_datetime).with('1640995200').and_return(DateTime.new(2022, 1, 1))
          
          result = controller.send(:apply_filters, collection)
          expect(collection.where_conditions).not_to be_empty
        end

        it 'converts multiple ranges for between predicate' do
          controller.params = ActionController::Parameters.new(filter: { created_at: ['1609459200,1640995200', '1672531200,1704067200'] })
          
          expect(controller).to receive(:foa_string_to_datetime).exactly(4).times.and_return(DateTime.new(2021, 1, 1))
          
          result = controller.send(:apply_filters, collection)
          expect(collection.where_conditions).not_to be_empty
        end
      end
    end

    describe 'string format (default)' do
      before do
        MockController.filters_configuration = {}
        MockController.filter_by :name, with: :eq, format: :string
      end

      it 'does not convert string values' do
        controller.params = ActionController::Parameters.new(filter: { name: 'john' })
        
        expect(controller).not_to receive(:foa_string_to_datetime)
        
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end
    end

    describe 'array format' do
      before do
        MockController.filters_configuration = {}
        MockController.filter_by :tags, with: :in, format: :array
      end

      it 'does not convert array values during filtering' do
        controller.params = ActionController::Parameters.new(filter: { tags: ['tag1', 'tag2'] })
        
        expect(controller).not_to receive(:foa_string_to_datetime)
        
        result = controller.send(:apply_filters, collection)
        expect(collection.where_conditions).not_to be_empty
      end
    end

    describe '#apply_format_conversion' do
      it 'converts string to datetime when format is :datetime' do
        expect(controller).to receive(:foa_string_to_datetime).with('1609459200').and_return(DateTime.new(2021, 1, 1))
        
        result = controller.send(:apply_format_conversion, '1609459200', :datetime)
        expect(result).to be_a(DateTime)
      end

      it 'converts array elements to datetime when format is :datetime' do
        expect(controller).to receive(:foa_string_to_datetime).with('1609459200').and_return(DateTime.new(2021, 1, 1))
        expect(controller).to receive(:foa_string_to_datetime).with('1640995200').and_return(DateTime.new(2022, 1, 1))
        
        result = controller.send(:apply_format_conversion, ['1609459200', '1640995200'], :datetime)
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first).to be_a(DateTime)
      end

      it 'returns value unchanged when format is :string' do
        result = controller.send(:apply_format_conversion, 'test_value', :string)
        expect(result).to eq('test_value')
      end

      it 'returns value unchanged when format is :array' do
        result = controller.send(:apply_format_conversion, ['value1', 'value2'], :array)
        expect(result).to eq(['value1', 'value2'])
      end

      it 'returns value unchanged when format is not recognized' do
        result = controller.send(:apply_format_conversion, 'test_value', :unknown)
        expect(result).to eq('test_value')
      end
    end
  end
end
