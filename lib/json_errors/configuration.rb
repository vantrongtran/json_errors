# frozen_string_literal: true

module JsonErrors
  class Configuration < Module
    def initialize(**attributes)
      attributes.each do |name, default|
        define_reader(name, default)
        define_writer(name)
      end
      define_reader(:error_setting, {})
      define_writer(:error_setting)
      define_reader(
        :http_status,
        Rack::Utils::HTTP_STATUS_CODES.transform_values { |e| e.delete(' ').underscore.to_sym }
      )
    end

    private

    def define_reader(name, default)
      variable = :"@#{name}"

      define_method(name) do
        if instance_variable_defined?(variable)
          instance_variable_get(variable)
        else
          default
        end
      end
    end

    def define_writer(name)
      variable = :"@#{name}"

      define_method("#{name}=") do |value|
        instance_variable_set(variable, value)
      end
    end
  end
end
