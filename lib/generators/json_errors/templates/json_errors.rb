# frozen_string_literal: true

# Configuration for the json_errors gem.
# Every option below is commented out and shows its default value.
# Uncomment and change only the options you want to override.
JsonErrors.setup do |config|
  # Controller method used to render the error response.
  # It is called with the hash returned by the handler, e.g. { json: {...}, status: :bad_request }.
  # config.renderer = :render

  # HTTP status used by `raise_jerror` when no `status:` is given,
  # and by the default handler for exceptions other than ActiveRecord::RecordNotFound.
  # config.default_error_status = :bad_request

  # Callable invoked with every rescued exception before the response is rendered.
  # config.log_error = ->(_exception) {}

  # Callable building the response for errors raised by `raise_jerror` (JsonErrors::JError).
  # config.jerror_handler = JsonErrors.handle_jerror

  # Callable building the response for ActiveRecord::RecordInvalid.
  # config.invalid_record_handler = JsonErrors.handle_invalid_record

  # Callable building the response for any other StandardError.
  # config.other_exception_handler = JsonErrors.handle_other_exception
end
