# frozen_string_literal: true

module JsonErrors
  class JError < StandardError
    def initializer(name, status, options)
      self.name = name
      self.status = status
      self.options = options
    end

    attr_reader :name, :status, :options
  end
end
