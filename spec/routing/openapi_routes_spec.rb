# frozen_string_literal: true

require 'rails_helper'

# The application has a catch-all route: match '*path' => 'application#routing_error'
# This means `not_to be_routable` never works since all paths technically match.
# Instead, we assert that blocked routes fall through to the catch-all routing_error.
#
# Note: Rswag::Ui::Engine mount cannot be tested here because Rails engine mounts
# don't re-register during reload_routes!. The Swagger mount lives inside the same
# conditional block as the openapi/apidocs routes, so it follows the same restrictions.

RSpec.describe 'OpenAPI and Swagger documentation routes', type: :routing do
  describe 'environment-based access restrictions' do
    after do
      # Restore Settings to original state and reload routes for the test environment
      # This prevents route state from leaking into subsequent specs
      allow(Settings).to receive(:vsp_environment).and_call_original
      Rails.application.reload_routes!
    end

    context 'in development environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('localhost')
        Rails.application.reload_routes!
      end

      it 'mounts the openapi route' do
        expect(get: '/v0/openapi').to route_to(
          controller: 'v0/open_api',
          action: 'index',
          format: 'json'
        )
      end

      it 'mounts the v0 apidocs route' do
        expect(get: '/v0/apidocs').to route_to(
          controller: 'v0/apidocs',
          action: 'index',
          format: 'json'
        )
      end

      it 'mounts the v1 apidocs route' do
        expect(get: '/v1/apidocs').to route_to(
          controller: 'v1/apidocs',
          action: 'index',
          format: 'json'
        )
      end
    end

    context 'in test environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('test')
        Rails.application.reload_routes!
      end

      it 'mounts the openapi route' do
        expect(get: '/v0/openapi').to route_to(
          controller: 'v0/open_api',
          action: 'index',
          format: 'json'
        )
      end
    end

    context 'in production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
        Rails.application.reload_routes!
      end

      it 'routes openapi to the catch-all error handler' do
        expect(get: '/v0/openapi').to route_to(
          controller: 'application', action: 'routing_error', path: 'v0/openapi'
        )
      end

      it 'routes v0 apidocs to the catch-all error handler' do
        expect(get: '/v0/apidocs').to route_to(
          controller: 'application', action: 'routing_error', path: 'v0/apidocs'
        )
      end

      it 'routes v1 apidocs to the catch-all error handler' do
        expect(get: '/v1/apidocs').to route_to(
          controller: 'application', action: 'routing_error', path: 'v1/apidocs'
        )
      end

      it 'routes swagger to the catch-all error handler' do
        expect(get: '/v0/swagger').to route_to(
          controller: 'application', action: 'routing_error', path: 'v0/swagger'
        )
      end
    end

    context 'in staging environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('staging')
        Rails.application.reload_routes!
      end

      it 'routes openapi to the catch-all error handler' do
        expect(get: '/v0/openapi').to route_to(
          controller: 'application', action: 'routing_error', path: 'v0/openapi'
        )
      end

      it 'routes v0 apidocs to the catch-all error handler' do
        expect(get: '/v0/apidocs').to route_to(
          controller: 'application', action: 'routing_error', path: 'v0/apidocs'
        )
      end

      it 'routes v1 apidocs to the catch-all error handler' do
        expect(get: '/v1/apidocs').to route_to(
          controller: 'application', action: 'routing_error', path: 'v1/apidocs'
        )
      end

      it 'routes swagger to the catch-all error handler' do
        expect(get: '/v0/swagger').to route_to(
          controller: 'application', action: 'routing_error', path: 'v0/swagger'
        )
      end
    end
  end
end
