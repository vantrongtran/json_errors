# frozen_string_literal: true

module JsonErrors
  class Railtie < ::Rails::Railtie
    def preload
      initializer = ::Rails.root.join('config', 'initializers', 'json_errors.rb')
      require initializer if File.exist?(initializer)

      JsonErrors.load_and_set_settings
    end

    config.before_configuration { preload }

    if ::Rails.env.development?
      initializer :config_reload_on_development do
        %i[action_controller_base action_controller_api].each do |action_controller|
          ActiveSupport.on_load(action_controller) do
            if ::Rails::VERSION::MAJOR >= 4
              prepend_before_action { JsonErrors.reload! }
            else
              prepend_before_filter { JsonErrors.reload! }
            end
          end
        end
      end
    end
  end
end
