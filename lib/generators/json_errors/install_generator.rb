# require 'rails/generators'

module JsonErrors
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      def self.source_root
        @_config_source_root ||= File.expand_path("../templates", __FILE__)
      end

      def copy_initializer
        template "json_errors.rb", "config/initializers/json_errors.rb"
      end

      def copy_settings
        template "error_codes.yml", "config/error_codes.yml"
        template "errors.en.yml", "config/locales/errors.en.yml"
      end
    end
  end
end
