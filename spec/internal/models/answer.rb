# frozen_string_literal: true

class Answer < ActiveRecord::Base
  #
  # Validations
  #
  validates :content,
            presence: true

  #
  # Associations
  #
  belongs_to :question,
             class_name: 'Question',
             foreign_key: 'question_id',
             inverse_of: :answer
end
