# frozen_string_literal: true

require 'spec_helper'
require 'internal/controllers/questions_controller'

RSpec.describe QuestionsController, type: :controller do
  context '' do
    describe "GET index" do
      it "returns redirect_to sign_in" do
        get :index
        # response.should redirect_to new_user_session_path
      end
    end
  end
end
