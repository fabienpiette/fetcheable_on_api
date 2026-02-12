# frozen_string_literal: true

# Shared test helpers and mock classes
module TestHelpers
  # Mock ActionController::Parameters for testing
  class MockParams < Hash
    def initialize(params = {})
      super()
      params.each do |key, value|
        self[key] = value.is_a?(Hash) ? MockParams.new(value) : value
      end
    end

    def require(key)
      self[key] || raise(ActionController::ParameterMissing, key)
    end

    def permit(*keys)
      result = MockParams.new
      keys.each do |key|
        if key.is_a?(Hash)
          key.each_key do |k|
            result[k] = self[k] if key?(k)
          end
        elsif key?(key)
          result[key] = self[key]
        end
      end
      result
    end

    def to_hash
      to_h
    end

    def dig(*keys)
      keys.reduce(self) { |memo, key| memo.is_a?(Hash) ? memo[key] : nil }
    end

    def blank?
      empty?
    end

    def fetch(key, default = nil)
      super
    end
  end
end

# Mock ActionController for parameter errors
unless defined?(ActionController)
  module ActionController
    class ParameterMissing < StandardError; end

    class Parameters < Hash
      def self.new(params = {})
        TestHelpers::MockParams.new(params)
      end
    end
  end
end
