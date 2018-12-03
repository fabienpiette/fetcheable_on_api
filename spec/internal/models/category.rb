# frozen_string_literal: true

class Category < ActiveRecord::Base
  #
  # Validations
  #
  validates :name,
            presence: true

  #
  # Associations
  #
  has_many :questions,
           class_name: 'Question',
           inverse_of: :category
end
