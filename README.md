# JsonErrors

`json_errors` gives a Rails API a single, consistent JSON format for errors.

Include `JsonErrors` in a controller and every `StandardError` raised by an action is rescued and rendered as:

```json
{
  "errors": [
    { "code": "ECODE01", "message": "Human readable message" }
  ]
}
```

- **Error codes** are looked up in `config/error_codes.yml`, grouped by HTTP status name.
- **Messages** come from I18n (`errors.messages.*` and `errors.jmessages.*`).
- **Custom business errors** are raised with `raise_jerror`.
- **Validation errors** (`ActiveRecord::RecordInvalid`) are rendered per field, with status `422`.

## Requirements

- Ruby >= 2.6
- A Rails application using ActiveRecord (the gem relies on Rails, ActiveSupport, ActiveRecord, Rack and I18n being loaded by the host app)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'json_errors'
```

Or, to use the source from GitHub:

```ruby
gem 'json_errors', git: 'https://github.com/vantrongtran/json_errors'
```

And then execute:

    $ bundle install

Then run the install generator:

    $ rails generate json_errors:install

The generator creates 3 files:

| File | Purpose |
| --- | --- |
| `config/initializers/json_errors.rb` | Configuration (`JsonErrors.setup`). Generated empty; add your settings here. |
| `config/error_codes.yml` | Error codes, grouped by HTTP status name. |
| `config/locales/errors.en.yml` | English error messages (`errors.messages` and `errors.jmessages`). |

## Configuration

Configure the gem in `config/initializers/json_errors.rb`. Every option is optional; the example below shows the 6 options with their default values:

```ruby
# config/initializers/json_errors.rb
JsonErrors.setup do |config|
  # Controller method called with the serialized error, e.g. render(json: ..., status: ...)
  config.renderer = :render

  # HTTP status used when no status can be determined
  config.default_error_status = :bad_request

  # Called with every rescued exception before it is rendered
  config.log_error = ->(_exception) {}

  # Builds the response for errors raised with `raise_jerror`
  config.jerror_handler = ->(exception) { JsonErrors::Serializer::JError.serialize(exception) }

  # Builds the response for ActiveRecord::RecordInvalid
  config.invalid_record_handler = ->(exception) { JsonErrors::Serializer::InvalidRecord.serialize(exception) }

  # Builds the response for any other exception
  config.other_exception_handler = ->(exception) { JsonErrors::Serializer::Base.serialize(exception) }
end
```

| Option | Default | Description |
| --- | --- | --- |
| `renderer` | `:render` | Name of the controller method that receives the hash returned by a handler (`send(renderer, response)`). With the default handlers the hash is `{ json: { errors: [...] }, status: <symbol> }`, which `render` accepts directly. |
| `default_error_status` | `:bad_request` | Status used for exceptions that are not `ActiveRecord::RecordNotFound`, and for `raise_jerror` when no `status:` is given. |
| `log_error` | `->(_exception) {}` (does nothing) | Lambda called with the exception before rendering. Use it to log or report errors, e.g. `->(exception) { Rails.logger.error(exception.message) }`. |
| `jerror_handler` | lambda calling `JsonErrors::Serializer::JError.serialize(exception)` | Handles `JsonErrors::JError` (raised by `raise_jerror`). |
| `invalid_record_handler` | lambda calling `JsonErrors::Serializer::InvalidRecord.serialize(exception)` | Handles `ActiveRecord::RecordInvalid`. |
| `other_exception_handler` | lambda calling `JsonErrors::Serializer::Base.serialize(exception)` | Handles every other `StandardError`. |

Each handler is a callable that receives the exception and returns the value passed to `renderer`.

**Note:** `JsonErrors.setup` only runs its block the **first time** it is called; later calls are ignored. The gem's Railtie loads `config/initializers/json_errors.rb` early (before Rails configuration), so this guard prevents the block from running twice when Rails loads the initializer again. If you need to change a setting afterwards, assign it directly, e.g. `JsonErrors.default_error_status = :unprocessable_entity`.

## Usage

### Rescuing errors in controllers

Include `JsonErrors` in your base controller. It adds `rescue_from StandardError, with: :rescue_error`, so every error raised by an action goes through the flow below:

1. `JsonErrors.log_error` is called with the exception.
2. A handler is chosen by exception class:
   - `JsonErrors::JError` → `jerror_handler`
   - `ActiveRecord::RecordInvalid` → `invalid_record_handler`
   - anything else → `other_exception_handler`
3. The handler's result is passed to the controller method named by `renderer` (`render` by default).

```ruby
class ApplicationController < ActionController::API
  include JsonErrors
end
```

### Raising custom errors with `raise_jerror`

```ruby
raise_jerror(name, status: JsonErrors.default_error_status, options: {})
```

- `name`: the error name (symbol). It is used to look up the code in `config/error_codes.yml` and the message at the I18n key `errors.jmessages.<name>`.
- `status`: HTTP status. It accepts either a symbol (`:not_found`) or an HTTP status number (`404`). Numbers are converted to the matching symbol using Rack's status table (`Rack::Utils::HTTP_STATUS_CODES`): `404` becomes `:not_found`, `403` becomes `:forbidden`, and so on. The resolved symbol is also the group name used in `config/error_codes.yml`. Defaults to `JsonErrors.default_error_status`.
- `options`: a hash passed to I18n as interpolation variables for `errors.jmessages.<name>`.

```ruby
class PostsController < ApplicationController
  def show
    post = Post.find(params[:id]) # ActiveRecord::RecordNotFound is rendered automatically

    # status as a number: 404 is converted to :not_found
    raise_jerror(:post_not_published, status: 404, options: { id: post.id }) unless post.published?

    render json: post
  end

  def index
    if params[:from].to_s > params[:to].to_s
      # no status given: uses JsonErrors.default_error_status (:bad_request)
      raise_jerror(:invalid_date_range, options: { from: params[:from], to: params[:to] })
    end

    render json: Post.all
  end

  def create
    # status as a symbol
    raise_jerror(:post_limit_reached, status: :unprocessable_entity, options: { limit: 10 }) if Post.count >= 10

    post = Post.create!(post_params) # ActiveRecord::RecordInvalid is rendered automatically
    render json: post, status: :created
  end
end
```

## Error codes and messages

### Error codes: `config/error_codes.yml`

Codes are grouped by the HTTP status **name** (the status symbol as a string). The code of an error is looked up as `error_codes[<status>][<error name>]`:

| Error | Status group | Error name |
| --- | --- | --- |
| `raise_jerror(:name, ...)` | the resolved status, e.g. `not_found` | `name` |
| `ActiveRecord::RecordNotFound` | `not_found` | `record_not_found` |
| `ActiveRecord::RecordInvalid` | `unprocessable_entity` | the validation error type of each field (`blank`, `taken`, ...) |
| any other exception | `default_error_status` (`bad_request` by default) | last part of the class name, underscored (`ActionController::ParameterMissing` → `parameter_missing`) |

```yaml
# config/error_codes.yml
not_found:
  record_not_found: ECODE01
  post_not_published: ECODE02
bad_request:
  parameter_missing: ECODE10
  invalid_date_range: ECODE11
unprocessable_entity:
  blank: ECODE20
  taken: ECODE21
  too_long: ECODE22
  post_limit_reached: ECODE23
```

If no code is defined for an error, `code` is `null` in the response.

The file is loaded when the application boots. In the `development` environment it is reloaded before every request (`JsonErrors.reload!`), so changes are picked up without restarting the server.

### Messages: `config/locales/errors.en.yml`

- `errors.messages.<error name>`: messages for normal exceptions (e.g. `record_not_found`, `parameter_missing`) **and** for validation errors (`blank`, `taken`, ...; `%{attribute}` is the attribute name).
- `errors.jmessages.<name>`: messages for errors raised with `raise_jerror`; the `options` hash is used for interpolation.

```yaml
# config/locales/errors.en.yml
en:
  errors:
    format: "%{message}"
    messages:
      # normal exceptions
      record_not_found: "Record not found"
      parameter_missing: "Required parameter is missing"
      # validation errors
      required: "%{attribute} is require"
      blank: "%{attribute} cannot be blank"
      taken: "%{attribute} already exists in the system"
      too_long: "%{attribute} too long"
      too_short: "%{attribute} too short"
    jmessages:
      post_not_published: "Post %{id} is not published"
      invalid_date_range: "Invalid date range: %{from} - %{to}"
      post_limit_reached: "You can create at most %{limit} posts"
```

If a translation is missing, the `message` contains I18n's "translation missing" text for that key.

## JSON responses

Each default handler returns `{ json: { errors: [...] }, status: <status> }`, which is passed to `render`.

### (a) `raise_jerror` or any other exception

`JsonErrors::Serializer::JError` and `JsonErrors::Serializer::Base` return one element with `code` and `message`.

`raise_jerror(:post_not_published, status: 404, options: { id: 42 })` → HTTP `404 Not Found`:

```json
{
  "errors": [
    { "code": "ECODE02", "message": "Post 42 is not published" }
  ]
}
```

An `ActionController::ParameterMissing` exception → HTTP `400 Bad Request` (`default_error_status`):

```json
{
  "errors": [
    { "code": "ECODE10", "message": "Required parameter is missing" }
  ]
}
```

### (b) `ActiveRecord::RecordInvalid`

`JsonErrors::Serializer::InvalidRecord` always responds with status `:unprocessable_entity` (HTTP `422`) and returns one element per invalid field:

- `code`: looked up in `unprocessable_entity` using the field's first validation error type
- `resource`: the model class name, underscored (`User` → `user`)
- `field`: the attribute name
- `message`: the field's first error message

`User.create!(email: "", name: "john")` where `email` is blank and `name` is already taken → HTTP `422`:

```json
{
  "errors": [
    { "code": "ECODE20", "resource": "user", "field": "email", "message": "Email cannot be blank" },
    { "code": "ECODE21", "resource": "user", "field": "name", "message": "Name already exists in the system" }
  ]
}
```

### (c) `ActiveRecord::RecordNotFound`

`JsonErrors::Serializer::Base` responds with status `:not_found` (HTTP `404`); the code is looked up as `not_found.record_not_found` and the message as `errors.messages.record_not_found`.

`Post.find(0)` → HTTP `404 Not Found`:

```json
{
  "errors": [
    { "code": "ECODE01", "message": "Record not found" }
  ]
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vantrongtran/json_errors.
