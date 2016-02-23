require "excon"
require "rack"

require "rack/forwarder/version"
require "rack/forwarder/matcher"
require "rack/forwarder/registry"

module Rack
  class Forwarder
    HEADERS_TO_FORWARD = %w(
      Content-Type
      Content-Length
    )

    def initialize(app, options = {}, &block)
      @app = app
      @options = options
      instance_eval(&block)
    end

    def forward(regexp, to:)
      @from = regexp
      @to = to
    end

    def call(env)
      request = Request.new(env)
      return @app.call(env) if @from.match(request.path).nil?

      request_method = request.request_method.to_s.downcase
      options = {
        body: request.body.read,
        headers: extract_http_headers(env),
      }.merge(@options)
      response = Excon.public_send(
        request_method,
        @to,
        options,
      )

      [response.status, headers_from_response(response.headers), [response.body]]
    end

    private

    def extract_http_headers(env)
      headers = env.each_with_object(Utils::HeaderHash.new) do |(key, value), hash|
        if key =~ /HTTP_(.*)/
          if $1 != 'HOST'
            hash[$1] = value
          end
        end
      end
      headers["X-Request-Id"] = env["action_dispatch.request_id"]

      headers
    end

    def headers_from_response(headers)
      HEADERS_TO_FORWARD.each_with_object(Utils::HeaderHash.new) do |header, hash|
        value = headers[header]
        hash[header] = value if value
      end
    end
  end
end
