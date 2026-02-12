# frozen_string_literal: true

RSpec.describe FetcheableOnApi do
  it 'has a version number' do
    expect(FetcheableOnApi::VERSION).not_to be_nil
  end

  describe '#configure' do
    before do
      described_class.configure do |config|
        config.pagination_default_size = 30
      end
    end

    it 'can define custome pagination_default_size' do
      config = described_class.configuration

      expect(config.pagination_default_size).to eq(30)
    end
  end
end
