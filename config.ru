# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'rails'

Bundler.require :default, :development

# Combustion.initialize! :all
Combustion.initialize! :active_record, :action_controller, :sprockets

run Combustion::Application
