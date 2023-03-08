# frozen_string_literal: true

require 'json_errors/version'
require 'json_errors/configuration'
require 'json_errors/j_error'
require 'json_errors/serializer/base'
require 'json_errors/serializer/j_error'
require 'json_errors/serializer/invalid_record'
require 'yaml'

module JsonErrors
  extend ActiveSupport::Concern

  def self.handle_jerror
    lambda do |exception|
      JsonErrors::Serializer::JError.serialize(exception)
    end
  end

  def self.handle_invalid_record
    lambda do |exception|
      JsonErrors::Serializer::InvalidRecord.serialize(exception)
    end
  end

  def self.handle_other_exception
    lambda do |exception|
      JsonErrors::Serializer::Base.serialize(exception)
    end
  end

  extend JsonErrors::Configuration.new(
    renderer: :render,
    default_error_status: :bad_request,
    log_error: ->(_exception) {},
    jerror_handler: JsonErrors.handle_jerror,
    invalid_record_handler: JsonErrors.handle_invalid_record,
    other_exception_handler: JsonErrors.handle_other_exception
  )

  included do
    rescue_from StandardError, with: :rescue_error
  end

  def self.setup
    yield self unless @_ran_once
    @_ran_once = true
  end

  def raise_jerror(name, status: JsonErrors.default_error_status, options: {})
    raise JsonErrors::JError.new(name: name, status: status, options: options)
  end

  def rescue_error(exception)
    JsonErrors.log_error.call(exception)
    send(JsonErrors.renderer, error_response(exception))
  end

  def error_response(exception)
    case exception
    when JsonErrors::JError
      JsonErrors.jerror_handler.call(exception)
    when ActiveRecord::RecordInvalid
      JsonErrors.invalid_record_handler.call(exception)
    else
      JsonErrors.other_exception_handler.call(exception)
    end
  end

  def self.load_config_files!
    code_file = ::Rails.root.join('config', 'error_codes.yml')
    File.exist?(code_file) ? YAML.load_file(code_file) : {}
  end

  def self.load_and_set_settings
    JsonErrors.load_error_setting
  end

  def self.reload!
    JsonErrors.load_error_setting
  end

  def self.load_error_setting
    @error_setting = JsonErrors.load_config_files!
  end
end

require('json_errors/railtie') if defined?(::Rails::Railtie)
