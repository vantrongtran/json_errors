# frozen_string_literal: true

module JsonErrors
  class JError < StandardError
    def initialize(name:, status:, options:)
      @name = name
      @status = status
      @options = options
    end

    attr_reader :name, :status, :options
  end
end
