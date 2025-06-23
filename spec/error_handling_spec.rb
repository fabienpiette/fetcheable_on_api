# frozen_string_literal: true

require 'spec_helper'

# Mock classes for error handling testing
class MockResponse
  attr_accessor :headers
  
  def initialize
    @headers = {}
  end
end

class MockExceptCollection
  def initialize(count_value = 100, should_error = false)
    @count_value = count_value
    @should_error = should_error
  end

  def count
    if @should_error
      raise StandardError, 'Database error'
    else
      @count_value
    end
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
  attr_reader :column, :direction

  def initialize(column, direction)
    @column = column
    @direction = direction
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
class MockErrorController
  include FetcheableOnApi

  attr_accessor :params, :response

  def initialize(params = {})
    @params = ActionController::Parameters.new(params)
    @response = MockResponse.new
  end
end

class MockErrorCollection
  attr_reader :klass

  def initialize(klass = MockActiveRecord)
    @klass = klass
  end

  def name
    MockClassName.new(@klass)
  end

  def joins(association)
    raise ActiveRecord::AssociationNotFoundError, "Association '#{association}' not found" if association == :invalid_association

    self
  end

  def where(_conditions)
    self
  end

  def order(_ordering)
    self
  end

  def limit(_value)
    self
  end

  def offset(_value)
    self
  end

  def except(*_args)
    MockExceptCollection.new(100)
  end

  def count
    100
  end
end

RSpec.describe 'FetcheableOnApi Error Handling' do
  let(:controller) { MockErrorController.new }
  let(:collection) { MockErrorCollection.new }

  describe 'FetcheableOnApi::ArgumentError' do
    it 'is a subclass of ArgumentError' do
      expect(FetcheableOnApi::ArgumentError.new).to be_a(ArgumentError)
    end

    it 'can be raised with custom messages' do
      expect do
        raise FetcheableOnApi::ArgumentError, 'Custom error message'
      end.to raise_error(FetcheableOnApi::ArgumentError, 'Custom error message')
    end
  end

  describe 'FetcheableOnApi::NotImplementedError' do
    it 'is a subclass of NotImplementedError' do
      expect(FetcheableOnApi::NotImplementedError.new).to be_a(NotImplementedError)
    end

    it 'can be raised with custom messages' do
      expect do
        raise FetcheableOnApi::NotImplementedError, 'Feature not implemented'
      end.to raise_error(FetcheableOnApi::NotImplementedError, 'Feature not implemented')
    end
  end

  describe 'Parameter validation errors' do
    describe '#foa_valid_parameters!' do
      context 'with invalid parameter types' do
        it 'raises ArgumentError for invalid filter type' do
          controller.params = ActionController::Parameters.new(filter: 'string_instead_of_hash')

          expect do
            controller.send(:foa_valid_parameters!, :filter)
          end.to raise_error(FetcheableOnApi::ArgumentError, /Incorrect type String for params/)
        end

        it 'raises ArgumentError for invalid pagination type' do
          controller.params = ActionController::Parameters.new(page: 'string_instead_of_hash')

          expect do
            controller.send(:foa_valid_parameters!, :page)
          end.to raise_error(FetcheableOnApi::ArgumentError, /Incorrect type String for params/)
        end

        it 'raises ArgumentError for invalid sort type' do
          controller.params = ActionController::Parameters.new(sort: ['array_instead_of_string'])

          expect do
            controller.send(:foa_valid_parameters!, :sort, foa_permitted_types: [String])
          end.to raise_error(FetcheableOnApi::ArgumentError, /Incorrect type Array for params/)
        end
      end

      context 'with nested invalid parameters' do
        it 'validates nested parameter structure' do
          controller.params = ActionController::Parameters.new(
            filter: { name: { invalid: 'nested_structure' } }
          )

          MockErrorController.filter_by :name

          # Should not raise error during validation, but may during processing
          expect do
            controller.send(:foa_valid_parameters!, :filter)
          end.not_to raise_error
        end
      end
    end

    describe 'custom permitted types' do
      it 'validates against custom permitted types' do
        controller.params = ActionController::Parameters.new(custom_param: 123)

        expect do
          controller.send(:foa_valid_parameters!, :custom_param, foa_permitted_types: [String])
        end.to raise_error(FetcheableOnApi::ArgumentError)
      end

      it 'accepts valid custom types' do
        controller.params = ActionController::Parameters.new(custom_param: 'valid_string')

        expect do
          controller.send(:foa_valid_parameters!, :custom_param, foa_permitted_types: [String])
        end.not_to raise_error
      end
    end
  end

  describe 'Filterable error handling' do
    before do
      MockErrorController.filters_configuration = {}
    end

    describe 'unsupported predicates' do
      it 'raises ArgumentError for unsupported predicate symbols' do
        MockErrorController.filter_by :name, with: :unsupported_predicate
        controller.params = ActionController::Parameters.new(filter: { name: 'test' })

        expect do
          controller.send(:apply_filters, collection)
        end.to raise_error(ArgumentError, /unsupported predicate `unsupported_predicate`/)
      end

      it 'accepts lambda predicates without error' do
        custom_predicate = ->(_collection, _value) { MockArelPredicate.new('custom', 'name', 'test') }
        MockErrorController.filter_by :name, with: custom_predicate
        controller.params = ActionController::Parameters.new(filter: { name: 'test' })

        expect do
          controller.send(:apply_filters, collection)
        end.not_to raise_error
      end
    end

    describe 'invalid filter configuration' do
      it 'raises error for invalid filter options' do
        expect do
          MockErrorController.filter_by :name, invalid_option: 'value'
        end.to raise_error(ArgumentError)
      end

      it 'validates allowed keys in filter_by' do
        valid_options = %i[as class_name with format association]
        valid_options.each do |option|
          expect do
            MockErrorController.filter_by :name, option => 'value'
          end.not_to raise_error
        end
      end
    end

    describe 'missing filter configuration' do
      it 'ignores filters not configured' do
        # Don't configure any filters
        controller.params = ActionController::Parameters.new(filter: { unconfigured: 'value' })

        # Should process without error but not apply any filters
        result = controller.send(:apply_filters, collection)
        expect(result).to eq(collection)
      end
    end

    describe 'malformed filter values' do
      before do
        MockErrorController.filter_by :name
      end

      it 'handles empty filter values' do
        controller.params = ActionController::Parameters.new(filter: { name: '' })

        expect do
          controller.send(:apply_filters, collection)
        end.not_to raise_error
      end

      it 'handles nil filter values' do
        controller.params = ActionController::Parameters.new(filter: { name: nil })

        expect do
          controller.send(:apply_filters, collection)
        end.not_to raise_error
      end

      it 'handles array filter values when string expected' do
        controller.params = ActionController::Parameters.new(filter: { name: %w[array values] })

        expect do
          controller.send(:apply_filters, collection)
        end.not_to raise_error
      end
    end
  end

  describe 'Sortable error handling' do
    before do
      MockErrorController.sorts_configuration = {}
    end

    describe 'invalid sort configurations' do
      it 'ignores unconfigured sort fields' do
        controller.params = ActionController::Parameters.new(sort: 'unconfigured_field')

        result = controller.send(:apply_sort, collection)
        expect(result).to eq(collection)
      end

      it 'handles sort fields not present in model' do
        MockErrorController.sort_by :invalid_field
        controller.params = ActionController::Parameters.new(sort: 'invalid_field')

        # Should not raise error, just ignore the invalid field
        expect do
          controller.send(:apply_sort, collection)
        end.not_to raise_error
      end
    end

    describe 'malformed sort parameters' do
      before do
        MockErrorController.sort_by :name
      end

      it 'handles empty sort parameter' do
        controller.params = ActionController::Parameters.new(sort: '')

        expect do
          controller.send(:apply_sort, collection)
        end.not_to raise_error
      end

      it 'handles sort parameter with only commas' do
        controller.params = ActionController::Parameters.new(sort: ',,,')

        expect do
          controller.send(:apply_sort, collection)
        end.not_to raise_error
      end

      it 'handles sort parameter with mixed valid and invalid fields' do
        controller.params = ActionController::Parameters.new(sort: 'name,invalid_field,')

        expect do
          controller.send(:apply_sort, collection)
        end.not_to raise_error
      end
    end

    describe 'sort parameter format parsing' do
      it 'handles malformed sort direction indicators' do
        result = controller.send(:format_params, '++name,--email')

        # Should handle multiple prefix characters
        expect(result.keys).to include(:'+name'.to_sym, :'-email'.to_sym)
      end

      it 'handles empty field names' do
        result = controller.send(:format_params, ',+,-')

        # Should not crash on empty field names
        expect(result).to be_a(Hash)
      end
    end
  end

  describe 'Pageable error handling' do
    describe 'invalid pagination parameters' do
      it 'handles non-numeric page numbers' do
        controller.params = ActionController::Parameters.new(
          page: { number: 'invalid', size: 10 }
        )

        # to_i on 'invalid' returns 0
        limit, offset, count, page = controller.send(:extract_pagination_informations, collection)
        expect(page).to eq(0)
        expect(offset).to eq(-10) # (0 - 1) * 10
      end

      it 'handles non-numeric page sizes' do
        controller.params = ActionController::Parameters.new(
          page: { number: 1, size: 'invalid' }
        )

        # to_i on 'invalid' returns 0
        limit, offset, count, page = controller.send(:extract_pagination_informations, collection)
        expect(limit).to eq(0)
      end

      it 'handles negative page numbers' do
        controller.params = ActionController::Parameters.new(
          page: { number: -1, size: 10 }
        )

        limit, offset, count, page = controller.send(:extract_pagination_informations, collection)
        expect(page).to eq(-1)
        expect(offset).to eq(-20) # (-1 - 1) * 10
      end

      it 'handles zero page size' do
        controller.params = ActionController::Parameters.new(
          page: { number: 1, size: 0 }
        )

        limit, offset, count, page = controller.send(:extract_pagination_informations, collection)
        expect(limit).to eq(0)

        # This could cause division by zero in total pages calculation
        controller.send(:define_header_pagination, limit, 100, page)
        # Should handle gracefully without crashing
      end
    end

    describe 'collection count errors' do
      let(:error_collection) do
        MockErrorCollection.new.tap do |coll|
          def coll.except(*_args)
            MockExceptCollection.new(100, true)  # Pass count and error flag
          end
        end
      end

      it 'propagates collection count errors' do
        controller.params = ActionController::Parameters.new(
          page: { number: 1, size: 10 }
        )

        expect do
          controller.send(:extract_pagination_informations, error_collection)
        end.to raise_error(StandardError, 'Database error')
      end
    end
  end

  describe 'Integration error scenarios' do
    before do
      MockErrorController.filter_by :name
      MockErrorController.sort_by :name
    end

    it 'handles multiple parameter validation errors' do
      controller.params = ActionController::Parameters.new(
        filter: 'invalid',
        sort: { invalid: 'hash' },
        page: 'invalid'
      )

      # Should fail on first validation (filters)
      expect do
        controller.send(:apply_fetcheable, collection)
      end.to raise_error(FetcheableOnApi::ArgumentError)
    end

    it 'processes partial valid parameters when others are invalid' do
      MockErrorController.sorts_configuration = {}
      MockErrorController.sort_by :name

      controller.params = ActionController::Parameters.new(
        filter: { name: 'john' },
        sort: 'invalid_field', # This will be ignored
        page: { number: 1, size: 10 }
      )

      # Should process successfully, ignoring invalid sort field
      expect do
        controller.send(:apply_fetcheable, collection)
      end.not_to raise_error
    end
  end

  describe 'Edge cases and boundary conditions' do
    describe 'extremely large values' do
      it 'handles very large page numbers' do
        controller.params = ActionController::Parameters.new(
          page: { number: 999_999_999, size: 10 }
        )

        limit, offset, count, page = controller.send(:extract_pagination_informations, collection)
        expect(page).to eq(999_999_999)
        expect(offset).to eq(9_999_999_980) # Very large offset
      end

      it 'handles very large page sizes' do
        controller.params = ActionController::Parameters.new(
          page: { number: 1, size: 999_999_999 }
        )

        limit, offset, count, page = controller.send(:extract_pagination_informations, collection)
        expect(limit).to eq(999_999_999)
      end
    end

    describe 'unicode and special characters' do
      before do
        MockErrorController.filter_by :name
        MockErrorController.sort_by :name
      end

      it 'handles unicode in filter values' do
        controller.params = ActionController::Parameters.new(
          filter: { name: '测试,тест,🎉' }
        )

        expect do
          controller.send(:apply_filters, collection)
        end.not_to raise_error
      end

      it 'handles special characters in sort fields' do
        controller.params = ActionController::Parameters.new(sort: 'name,+name,-name')

        expect do
          controller.send(:apply_sort, collection)
        end.not_to raise_error
      end
    end

    describe 'memory and performance edge cases' do
      before do
        MockErrorController.filter_by :name
      end

      it 'handles very long filter value strings' do
        long_string = 'a' * 10_000
        controller.params = ActionController::Parameters.new(
          filter: { name: long_string }
        )

        expect do
          controller.send(:apply_filters, collection)
        end.not_to raise_error
      end

      it 'handles many comma-separated filter values' do
        many_values = Array.new(1000) { |i| "value#{i}" }.join(',')
        controller.params = ActionController::Parameters.new(
          filter: { name: many_values }
        )

        expect do
          controller.send(:apply_filters, collection)
        end.not_to raise_error
      end
    end
  end
end
