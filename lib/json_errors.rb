# frozen_string_literal: true

require 'json_errors/version'
require 'json_errors/configuration'
require 'yaml'

module JsonErrors
  extend ActiveSupport::Concern
  extend JsonErrors::Configuration.new(
    default_error_status: :bad_request
  )

  def self.setup
    yield self unless @_ran_once
    @_ran_once = true
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
