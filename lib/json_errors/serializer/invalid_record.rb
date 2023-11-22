# frozen_string_literal: true

module JsonErrors
  module Serializer
    class InvalidRecord < JsonErrors::Serializer::Base
      private

      def error_reponse
        record.errors.details.map do |field, details|
          {
            code: code(details.first[:error].to_s),
            resource: record.class.name.underscore,
            field: field,
            message: messages[field].first
          }
        end
      end

      def http_status
        :unprocessable_entity
      end

      def code(error_name)
        JsonErrors.error_setting.dig(http_status.to_s, error_name)
      end

      def record
        @record ||= error.record
      end

      def messages
        @messages ||= record.errors.to_hash
      end
    end
  end
end
