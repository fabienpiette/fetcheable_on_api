RSpec.describe FetcheableOnApi do
  it 'has a version number' do
    expect(FetcheableOnApi::VERSION).not_to be nil
  end

  describe '#configure' do
    before do
      FetcheableOnApi.configure do |config|
        config.pagination_default_size = 30
      end
    end

    it 'can define custome pagination_default_size' do
      config = FetcheableOnApi.configuration

      expect(config.pagination_default_size).to eq(30)
    end
  end
end
