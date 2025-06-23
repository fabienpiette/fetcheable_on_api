# frozen_string_literal: true

require 'spec_helper'

# Mock classes for testing Sortable (reusing some from filterable_spec)
class MockResponse
  attr_accessor :headers
  
  def initialize
    @headers = {}
  end
end
class MockSortableController
  include FetcheableOnApi

  attr_accessor :params, :response

  def initialize(params = {})
    @params = ActionController::Parameters.new(params)
    @response = MockResponse.new
  end
end

class MockSortableCollection
  attr_reader :klass, :order_applied

  def initialize(klass = MockActiveRecord)
    @klass = klass
    @order_applied = []
  end

  def order(ordering)
    @order_applied = ordering
    self
  end
end

class MockSortableArelColumn < MockArelColumn
  def lower
    MockLowerColumn.new(self)
  end

  def asc
    MockSortOrder.new(self, :asc)
  end

  def desc
    MockSortOrder.new(self, :desc)
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

class MockSortOrder
  attr_reader :column, :direction, :lower

  def initialize(column, direction, lower: false)
    @column = column
    @direction = direction
    @lower = lower
  end
end

class MockSortableArelTable < MockArelTable
  def [](column)
    MockSortableArelColumn.new(column, self)
  end
end

# Override the arel_table method for our mock classes
class MockActiveRecord
  def self.arel_table
    @arel_table ||= MockSortableArelTable.new(table_name)
  end
end

RSpec.describe FetcheableOnApi::Sortable do
  let(:controller) { MockSortableController.new }
  let(:collection) { MockSortableCollection.new }

  describe '.included' do
    it 'extends the class with ClassMethods' do
      expect(MockSortableController).to respond_to(:sort_by)
    end

    it 'adds sorts_configuration class attribute' do
      expect(MockSortableController).to respond_to(:sorts_configuration)
      expect(MockSortableController.sorts_configuration).to eq({})
    end
  end

  describe '.sort_by' do
    before do
      MockSortableController.sorts_configuration = {}
    end

    it 'configures simple sorts' do
      MockSortableController.sort_by :name, :email

      expect(MockSortableController.sorts_configuration[:name]).to eq(as: :name)
      expect(MockSortableController.sorts_configuration[:email]).to eq(as: :email)
    end

    it 'configures sorts with options' do
      MockSortableController.sort_by :name, as: 'full_name', lower: true

      expect(MockSortableController.sorts_configuration[:name]).to include(
        as: 'full_name',
        lower: true
      )
    end

    it 'configures sorts with class_name for associations' do
      MockSortableController.sort_by :category, class_name: MockCategory, as: 'name'

      expect(MockSortableController.sorts_configuration[:category]).to include(
        class_name: MockCategory,
        as: 'name'
      )
    end

    it 'merges options for existing sort configurations' do
      MockSortableController.sort_by :name, as: 'full_name'
      MockSortableController.sort_by :name, lower: true

      expect(MockSortableController.sorts_configuration[:name]).to include(
        as: 'full_name',
        lower: true
      )
    end
  end

  describe 'SORT_ORDER constant' do
    it 'maps + to asc and - to desc' do
      expect(FetcheableOnApi::Sortable::SORT_ORDER).to eq(
        '+' => :asc,
        '-' => :desc
      )
    end
  end

  describe '#apply_sort' do
    before do
      MockSortableController.sorts_configuration = {}
    end

    context 'when no sort params are present' do
      it 'returns the collection unchanged' do
        controller.params = ActionController::Parameters.new({})
        result = controller.send(:apply_sort, collection)
        expect(result).to eq(collection)
      end
    end

    context 'with simple sort parameter' do
      before do
        MockSortableController.sort_by :name
        controller.params = ActionController::Parameters.new(sort: 'name')
      end

      it 'applies ascending sort by default' do
        result = controller.send(:apply_sort, collection)
        expect(collection.order_applied).to be_an(Array)
        expect(collection.order_applied.first).to be_a(MockSortOrder)
        expect(collection.order_applied.first.direction).to eq(:asc)
      end
    end

    context 'with descending sort parameter' do
      before do
        MockSortableController.sort_by :name
        controller.params = ActionController::Parameters.new(sort: '-name')
      end

      it 'applies descending sort' do
        result = controller.send(:apply_sort, collection)
        expect(collection.order_applied.first.direction).to eq(:desc)
      end
    end

    context 'with multiple sort parameters' do
      before do
        MockSortableController.sort_by :name, :created_at
        controller.params = ActionController::Parameters.new(sort: 'name,-created_at')
      end

      it 'applies multiple sorts in order' do
        result = controller.send(:apply_sort, collection)
        expect(collection.order_applied).to have(2).items
        expect(collection.order_applied.first.direction).to eq(:asc)
        expect(collection.order_applied.last.direction).to eq(:desc)
      end
    end

    context 'with lowercase sort option' do
      before do
        MockSortableController.sort_by :name, lower: true
        controller.params = ActionController::Parameters.new(sort: 'name')
      end

      it 'applies lowercase sort' do
        result = controller.send(:apply_sort, collection)
        expect(collection.order_applied.first.lower).to be true
      end
    end

    context 'with association sort' do
      before do
        MockSortableController.sort_by :category, class_name: MockCategory, as: 'name'
        controller.params = ActionController::Parameters.new(sort: 'category')
      end

      it 'sorts by association field' do
        result = controller.send(:apply_sort, collection)
        expect(collection.order_applied).not_to be_empty
      end
    end

    context 'with unconfigured sort field' do
      before do
        controller.params = ActionController::Parameters.new(sort: 'unconfigured')
      end

      it 'ignores unconfigured sort fields' do
        result = controller.send(:apply_sort, collection)
        expect(collection.order_applied).to be_empty
      end
    end

    context 'with invalid sort parameter type' do
      before do
        MockSortableController.sort_by :name
        controller.params = ActionController::Parameters.new(sort: { name: 'asc' })
      end

      it 'raises parameter validation error' do
        expect do
          controller.send(:apply_sort, collection)
        end.to raise_error(FetcheableOnApi::ArgumentError)
      end
    end
  end

  describe '#format_params' do
    it 'parses single ascending field' do
      result = controller.send(:format_params, 'name')
      expect(result).to eq(name: :asc)
    end

    it 'parses single descending field' do
      result = controller.send(:format_params, '-name')
      expect(result).to eq(name: :desc)
    end

    it 'parses multiple fields' do
      result = controller.send(:format_params, 'name,-created_at,+updated_at')
      expect(result).to eq(
        name: :asc,
        created_at: :desc,
        updated_at: :asc
      )
    end

    it 'handles fields with explicit + prefix' do
      result = controller.send(:format_params, '+name')
      expect(result).to eq(name: :asc)
    end

    it 'handles empty strings' do
      result = controller.send(:format_params, '')
      expect(result).to eq('' => :asc)
    end

    it 'handles comma-separated with spaces' do
      result = controller.send(:format_params, 'name, -email')
      expect(result).to eq(
        name: :asc,
        ' -email': :desc
      )
    end
  end

  describe '#arel_sort' do
    let(:attr_name) { :name }
    let(:sort_method) { :asc }

    before do
      MockSortableController.sorts_configuration = {
        name: { as: :name }
      }
    end

    it 'returns nil for unconfigured attributes' do
      result = controller.send(:arel_sort, :unconfigured, sort_method, collection)
      expect(result).to be_nil
    end

    it 'returns nil for attributes not in model' do
      MockSortableController.sorts_configuration[:invalid] = { as: :invalid }
      result = controller.send(:arel_sort, :invalid, sort_method, collection)
      expect(result).to be_nil
    end

    it 'creates arel sort for valid attributes' do
      result = controller.send(:arel_sort, attr_name, sort_method, collection)
      expect(result).to be_a(MockSortOrder)
      expect(result.direction).to eq(:asc)
    end

    it 'applies lowercase when configured' do
      MockSortableController.sorts_configuration[:name][:lower] = true
      result = controller.send(:arel_sort, attr_name, sort_method, collection)
      expect(result.lower).to be true
    end
  end

  describe '#class_for' do
    before do
      MockSortableController.sorts_configuration = {
        category: { class_name: MockCategory }
      }
    end

    it 'returns configured class_name' do
      result = controller.send(:class_for, :category, collection)
      expect(result).to eq(MockCategory)
    end

    it 'returns collection klass when no class_name configured' do
      result = controller.send(:class_for, :name, collection)
      expect(result).to eq(collection.klass)
    end
  end

  describe '#field_for' do
    before do
      MockSortableController.sorts_configuration = {
        full_name: { as: 'name' }
      }
    end

    it 'returns configured field alias' do
      result = controller.send(:field_for, :full_name)
      expect(result).to eq('name')
    end

    it 'returns attribute name when no alias configured' do
      MockSortableController.sorts_configuration[:email] = { as: :email }
      result = controller.send(:field_for, :email)
      expect(result).to eq('email')
    end
  end

  describe '#belong_to_attributes_for?' do
    it 'returns true for valid model attributes' do
      result = controller.send(:belong_to_attributes_for?, MockActiveRecord, 'name')
      expect(result).to be true
    end

    it 'returns false for invalid model attributes' do
      result = controller.send(:belong_to_attributes_for?, MockActiveRecord, 'invalid_field')
      expect(result).to be false
    end
  end

  describe 'edge cases' do
    before do
      MockSortableController.sort_by :name
    end

    it 'handles empty sort parameter' do
      controller.params = ActionController::Parameters.new(sort: '')
      result = controller.send(:apply_sort, collection)
      expect(collection.order_applied).to be_empty
    end

    it 'handles sort parameter with only commas' do
      controller.params = ActionController::Parameters.new(sort: ',,,')
      result = controller.send(:apply_sort, collection)
      expect(collection.order_applied).to be_an(Array)
    end

    it 'handles sort parameter with mixed valid and invalid fields' do
      MockSortableController.sort_by :name
      controller.params = ActionController::Parameters.new(sort: 'name,invalid_field')
      result = controller.send(:apply_sort, collection)
      expect(collection.order_applied).to have(1).item
    end
  end

  describe 'integration with different collection types' do
    let(:custom_collection) { MockSortableCollection.new(MockCategory) }

    before do
      MockSortableController.sorts_configuration = {}
      MockSortableController.sort_by :name
    end

    it 'works with different collection classes' do
      controller.params = ActionController::Parameters.new(sort: 'name')
      result = controller.send(:apply_sort, custom_collection)
      expect(custom_collection.order_applied).not_to be_empty
    end
  end
end
