# frozen_string_literal: true

module JsonErrors
  module Serializer
    class Base
      def initialize(error)
        @error = error
      end

      def self.serialize(error)
        new(error).serialize
      end

      def serialize
        { json: { errors: error_reponse }, status: http_status }
      end

      private

      attr_reader :error

      def error_reponse
        [{
          code: code,
          message: message
        }]
      end

      def http_status
        case error
        when ActiveRecord::RecordNotFound
          :not_found
        else
          JsonErrors.default_error_status
        end
      end

      def code
        JsonErrors.error_setting.dig(http_status.to_s, error_name)
      end

      def message
        I18n.t("errors.messages.#{error_name}")
      rescue I18n::MissingTranslationData => e
        e.message
      end

      def error_name
        @error_name ||= error.class.name.split(/::/).last.underscore
      end
    end
  end
end
