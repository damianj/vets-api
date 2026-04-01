# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/snakecase'
require 'vass/response_middleware'

module Vass
  ##
  # Configuration class for VASS API clients.
  #
  # Singleton class providing Faraday connection setup with circuit breaker integration
  # and mock response support.
  #
  class Configuration < Common::Client::Configuration::REST
    include Singleton

    # Override default timeouts to handle external VASS API calls (D365 can exceed 30s).
    self.open_timeout = Settings.vass.open_timeout
    self.read_timeout = Settings.vass.read_timeout

    ##
    # Returns the base URL for VASS API requests.
    #
    # @return [String] The base URL for API requests
    #
    def base_path
      Settings.vass.api_url
    end

    ##
    # Returns the service name for circuit breaker and logging purposes.
    #
    # @return [String] The service name identifier
    #
    def service_name
      Settings.vass.service_name
    end

    ##
    # Creates and configures a Faraday connection with the complete middleware stack
    # for VASS JSON API requests. Includes camelcase/json request middleware for
    # automatic key transformation and body serialization.
    #
    # @param server_url [String] The base URL for the connection (defaults to base_path)
    # @return [Faraday::Connection] Configured HTTP connection (memoized per server_url)
    #
    def connection(server_url: base_path)
      build_pooled_connection(:__conn_pool__, server_url) do |conn|
        conn.request :camelcase
        conn.request :json
        conn.response :snakecase, symbolize: false
        conn.response :vass_errors
      end
    end

    ##
    # Faraday connection for Microsoft OAuth token requests only.
    # Omits camelcase/json request middleware so application/x-www-form-urlencoded bodies
    # (with literal keys grant_type, client_id, etc.) are not stripped or transformed.
    #
    # @param server_url [String] Microsoft login base URL (e.g. Settings.vass.auth_url)
    # @return [Faraday::Connection]
    #
    def oauth_connection(server_url:)
      build_pooled_connection(:__oauth_conn_pool__, server_url, request_opts: oauth_request_options)
    end

    private

    ##
    # Request timeouts for Microsoft OAuth token requests (separate from D365 API).
    #
    # @return [Hash] Faraday request options
    #
    def oauth_request_options
      {
        open_timeout: Settings.vass.oauth_open_timeout,
        timeout: Settings.vass.oauth_read_timeout
      }
    end

    def build_pooled_connection(pool_name, server_url, request_opts: nil)
      opts = request_opts || request_options
      pool = instance_variable_get("@#{pool_name}") || instance_variable_set("@#{pool_name}", {})
      pool[server_url] ||= Faraday.new(url: server_url, headers: base_request_headers,
                                       request: opts) do |conn|
        conn.use(:breakers, service_name:)
        yield conn if block_given?
        conn.response :raise_custom_error, error_prefix: service_name, include_request: true
        conn.response :json_parser
        conn.response :betamocks if mock_enabled?
        conn.adapter Faraday.default_adapter
      end
    end

    ##
    # Determines if mock responses should be enabled for API calls.
    # Checks both configuration setting and feature flag.
    #
    # @return [Boolean] true if mocking is enabled
    #
    def mock_enabled?
      Settings.vass.mock || Flipper.enabled?('vass_api_mock_enabled')
    end
  end
end
