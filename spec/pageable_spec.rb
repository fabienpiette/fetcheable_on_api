# frozen_string_literal: true

require 'spec_helper'

# Mock classes for testing Pageable
class MockPageableController
  include FetcheableOnApi

  attr_accessor :params, :response

  def initialize(params = {})
    @params = ActionController::Parameters.new(params)
    @response = MockResponse.new
  end
end

class MockResponse
  attr_accessor :headers

  def initialize
    @headers = {}
  end
end

class MockPageableCollection
  attr_reader :limit_value, :offset_value, :count_value, :limit_applied, :offset_applied

  def initialize(count = 100)
    @count_value = count
    @limit_applied = nil
    @offset_applied = nil
  end

  def limit(value)
    @limit_applied = value
    MockLimitedCollection.new(self, value)
  end

  def offset(value)
    @offset_applied = value
    MockOffsetCollection.new(self, value)
  end

  def except(*_args)
    MockExceptCollection.new(@count_value)
  end

  def count
    @count_value
  end
end

class MockLimitedCollection
  attr_reader :original_collection, :limit_value

  def initialize(original_collection, limit_value)
    @original_collection = original_collection
    @limit_value = limit_value
  end

  def offset(value)
    @original_collection.instance_variable_set(:@offset_applied, value)
    MockOffsetCollection.new(@original_collection, value, @limit_value)
  end
end

class MockOffsetCollection
  attr_reader :original_collection, :offset_value, :limit_value

  def initialize(original_collection, offset_value, limit_value = nil)
    @original_collection = original_collection
    @offset_value = offset_value
    @limit_value = limit_value
  end
end

class MockExceptCollection
  attr_reader :count_value

  def initialize(count_value = 100, should_error = false)
    @count_value = count_value
    @should_error = should_error
  end

  def count
    raise StandardError, 'Database error' if @should_error

    @count_value
  end
end

RSpec.describe FetcheableOnApi::Pageable do
  let(:controller) { MockPageableController.new }
  let(:collection) { MockPageableCollection.new(100) }

  describe '#apply_pagination' do
    context 'when no page params are present' do
      it 'returns the collection unchanged' do
        controller.params = ActionController::Parameters.new({})
        result = controller.send(:apply_pagination, collection)
        expect(result).to eq(collection)
      end
    end

    context 'when page params are blank' do
      it 'returns the collection unchanged' do
        controller.params = ActionController::Parameters.new(page: {})
        result = controller.send(:apply_pagination, collection)
        expect(result).to eq(collection)
      end
    end

    context 'with basic pagination params' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 2, size: 10 }
        )
      end

      it 'applies limit and offset' do
        controller.send(:apply_pagination, collection)
        expect(collection.limit_applied).to eq(10)
        expect(collection.offset_applied).to eq(10) # (page 2 - 1) * 10
      end

      it 'sets pagination headers' do
        controller.send(:apply_pagination, collection)
        headers = controller.response.headers

        expect(headers['Pagination-Current-Page']).to eq(2)
        expect(headers['Pagination-Per']).to eq(10)
        expect(headers['Pagination-Total-Pages']).to eq(10) # 100 / 10
        expect(headers['Pagination-Total-Count']).to eq(100)
      end
    end

    context 'with default pagination size' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 1 }
        )
      end

      it 'uses default pagination size from configuration' do
        controller.send(:apply_pagination, collection)
        expect(collection.limit_applied).to eq(FetcheableOnApi.configuration.pagination_default_size)
      end
    end

    context 'with first page' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 1, size: 20 }
        )
      end

      it 'applies zero offset for first page' do
        controller.send(:apply_pagination, collection)
        expect(collection.offset_applied).to eq(0)
      end

      it 'sets correct pagination headers' do
        controller.send(:apply_pagination, collection)
        headers = controller.response.headers

        expect(headers['Pagination-Current-Page']).to eq(1)
        expect(headers['Pagination-Per']).to eq(20)
        expect(headers['Pagination-Total-Pages']).to eq(5) # 100 / 20
        expect(headers['Pagination-Total-Count']).to eq(100)
      end
    end

    context 'with partial last page' do
      let(:collection) { MockPageableCollection.new(95) } # 95 records

      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 5, size: 20 }
        )
      end

      it 'calculates correct total pages for partial last page' do
        controller.send(:apply_pagination, collection)
        headers = controller.response.headers

        expect(headers['Pagination-Total-Pages']).to eq(5) # ceil(95 / 20)
      end
    end

    context 'with string parameters' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: '3', size: '15' }
        )
      end

      it 'converts string parameters to integers' do
        controller.send(:apply_pagination, collection)
        expect(collection.limit_applied).to eq(15)
        expect(collection.offset_applied).to eq(30) # (3 - 1) * 15
      end
    end

    context 'with invalid page parameter type' do
      before do
        controller.params = ActionController::Parameters.new(
          page: 'invalid'
        )
      end

      it 'raises parameter validation error' do
        expect do
          controller.send(:apply_pagination, collection)
        end.to raise_error(FetcheableOnApi::ArgumentError)
      end
    end
  end

  describe '#extract_pagination_informations' do
    context 'with complete pagination params' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 3, size: 20 }
        )
      end

      it 'extracts correct pagination information' do
        limit, offset, count, page = controller.send(:extract_pagination_informations, collection)

        expect(limit).to eq(20)
        expect(offset).to eq(40) # (3 - 1) * 20
        expect(count).to eq(100)
        expect(page).to eq(3)
      end
    end

    context 'with missing size parameter' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 2 }
        )
      end

      it 'uses default size from configuration' do
        limit, offset, = controller.send(:extract_pagination_informations, collection)

        expect(limit).to eq(FetcheableOnApi.configuration.pagination_default_size)
        expect(offset).to eq(FetcheableOnApi.configuration.pagination_default_size) # (2 - 1) * default_size
      end
    end

    context 'with missing number parameter' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { size: 15 }
        )
      end

      it 'defaults to page 1' do
        _, offset, _, page = controller.send(:extract_pagination_informations, collection)

        expect(page).to eq(1)
        expect(offset).to eq(0) # (1 - 1) * 15
      end
    end

    context 'with zero or negative page numbers' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 0, size: 10 }
        )
      end

      it 'handles zero page number' do
        _, offset, _, page = controller.send(:extract_pagination_informations, collection)

        expect(page).to eq(0)
        expect(offset).to eq(-10) # (0 - 1) * 10
      end
    end

    context 'with very large page numbers' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 1000, size: 10 }
        )
      end

      it 'handles large page numbers' do
        _, offset, _, page = controller.send(:extract_pagination_informations, collection)

        expect(page).to eq(1000)
        expect(offset).to eq(9990) # (1000 - 1) * 10
      end
    end
  end

  describe '#define_header_pagination' do
    before do
      controller.send(:define_header_pagination, 25, 100, 2)
    end

    it 'sets all required pagination headers' do
      headers = controller.response.headers

      expect(headers['Pagination-Current-Page']).to eq(2)
      expect(headers['Pagination-Per']).to eq(25)
      expect(headers['Pagination-Total-Pages']).to eq(4) # ceil(100 / 25)
      expect(headers['Pagination-Total-Count']).to eq(100)
    end

    context 'with exact division' do
      before do
        controller.response.headers = {}
        controller.send(:define_header_pagination, 20, 100, 1)
      end

      it 'calculates exact page count' do
        expect(controller.response.headers['Pagination-Total-Pages']).to eq(5)
      end
    end

    context 'with partial last page' do
      before do
        controller.response.headers = {}
        controller.send(:define_header_pagination, 30, 100, 1)
      end

      it 'rounds up for partial last page' do
        expect(controller.response.headers['Pagination-Total-Pages']).to eq(4) # ceil(100 / 30)
      end
    end

    context 'with single record' do
      before do
        controller.response.headers = {}
        controller.send(:define_header_pagination, 10, 1, 1)
      end

      it 'handles single record correctly' do
        expect(controller.response.headers['Pagination-Total-Pages']).to eq(1)
      end
    end

    context 'with zero records' do
      before do
        controller.response.headers = {}
        controller.send(:define_header_pagination, 10, 0, 1)
      end

      it 'handles zero records correctly' do
        expect(controller.response.headers['Pagination-Total-Pages']).to eq(0)
      end
    end
  end

  describe 'edge cases' do
    context 'with empty collection' do
      let(:collection) { MockPageableCollection.new(0) }

      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 1, size: 10 }
        )
      end

      it 'handles empty collections' do
        controller.send(:apply_pagination, collection)
        headers = controller.response.headers

        expect(headers['Pagination-Total-Count']).to eq(0)
        expect(headers['Pagination-Total-Pages']).to eq(0)
      end
    end

    context 'with very small page size' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 1, size: 1 }
        )
      end

      it 'handles page size of 1' do
        controller.send(:apply_pagination, collection)
        headers = controller.response.headers

        expect(headers['Pagination-Per']).to eq(1)
        expect(headers['Pagination-Total-Pages']).to eq(100)
      end
    end

    context 'with very large page size' do
      before do
        controller.params = ActionController::Parameters.new(
          page: { number: 1, size: 1000 }
        )
      end

      it 'handles very large page sizes' do
        controller.send(:apply_pagination, collection)
        headers = controller.response.headers

        expect(headers['Pagination-Per']).to eq(1000)
        expect(headers['Pagination-Total-Pages']).to eq(1)
      end
    end
  end

  describe 'integration with configuration' do
    context 'when configuration pagination_default_size is changed' do
      let(:original_size) { FetcheableOnApi.configuration.pagination_default_size }

      before do
        FetcheableOnApi.configuration.pagination_default_size = 50

        controller.params = ActionController::Parameters.new(
          page: { number: 1 }
        )
      end

      after do
        FetcheableOnApi.configuration.pagination_default_size = original_size
      end

      it 'uses the updated default size' do
        controller.send(:apply_pagination, collection)
        expect(collection.limit_applied).to eq(50)
      end
    end
  end

  describe 'collection interaction' do
    let(:collection) { MockPageableCollection.new(100) }

    before do
      controller.params = ActionController::Parameters.new(
        page: { number: 2, size: 15 }
      )
    end

    it 'calls except on collection to remove ordering for count' do
      allow(collection).to receive(:except).and_call_original
      controller.send(:apply_pagination, collection)
      expect(collection).to have_received(:except).with(:offset, :limit, :order)
    end

    it 'chains limit and offset methods correctly' do
      result = controller.send(:apply_pagination, collection)
      expect(result).to be_a(MockOffsetCollection)
      expect(result.limit_value).to eq(15)
      expect(result.offset_value).to eq(15)
    end
  end
end
