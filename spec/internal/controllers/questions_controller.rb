# frozen_string_literal: true

class QuestionsController < ActionController::Base
  # GET /questions
  def index
    # questions = Question.joins(:answer).includes(:answer).all
    questions = Question.all

    render json: questions
  end
end
