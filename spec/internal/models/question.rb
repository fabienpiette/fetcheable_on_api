# frozen_string_literal: true

class Question < ActiveRecord::Base
  #
  # Validations
  #
  validates :content,
            presence: true

  #
  # Associations
  #
  has_one :answer,
          class_name: 'Answer',
          foreign_key: 'question_id',
          dependent: :destroy,
          inverse_of: :question

  belongs_to :category,
             class_name: 'Category',
             inverse_of: :questions,
             optional: true
end
