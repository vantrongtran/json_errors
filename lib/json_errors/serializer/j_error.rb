# frozen_string_literal: true

module JsonErrors
  module Serializer
    class JError < JsonErrors::Serializer::Base
      private

      def http_status
        status = error.status || JsonErrors.default_error_status
        status = JsonErrors.http_status[status] if status.is_a?(Numeric)
        status
      end

      def code
        JsonErrors.error_setting.dig(http_status.to_s, error.name.to_s)
      end

      def message
        I18n.t("errors.jmessages.#{error.name}", error.options)
      rescue I18n::MissingTranslationData => e
        e.message
      end
    end
  end
end
