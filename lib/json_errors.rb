# frozen_string_literal: true

require 'json_errors/version'
require 'json_errors/configuration'
require 'json_errors/j_error'
require 'yaml'

module JsonErrors
  extend ActiveSupport::Concern

  def self.handle_jerror
    lambda do |exception|
      # Handle with custom error
    end
  end

  def self.handle_active_record_error
    lambda do |exception|
      # Handle with record error
    end
  end

  def self.handle_other_exception
    lambda do |exception|
      # Handle with exception error
    end
  end

  extend JsonErrors::Configuration.new(
    default_error_status: :bad_request,
    log_error: ->(_exception) {},
    jerror_handler: JsonErrors.handle_jerror,
    active_record_error_handler: JsonErrors.handle_active_record_error,
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
    case exception
    when JsonErrors::JError
      JsonErrors.jerror_handler.call(exception)
    when ActiveRecord::ActiveRecordError
      JsonErrors.active_record_error_handler.call(exception)
    else
      JsonErrors.other_exception_handler.call(exception)
    end
  end

  def self.load_config_files!
    code_file = ::Rails.root.join('config', 'error_codes.yml')
    YAML.load_file(code_file) if File.exist?(code_file)
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
