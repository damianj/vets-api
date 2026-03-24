# frozen_string_literal: true

##
# Shared helper for stubbing VASS settings in tests.
# This ensures consistent configuration across all VASS specs.
#
module VassSettingsHelper
  DEFAULT_VASS_SETTINGS = {
    auth_url: 'https://login.microsoftonline.us',
    tenant_id: 'test-tenant-id',
    client_id: 'test-client-id',
    client_secret: 'test-client-secret',
    jwt_secret: 'test-jwt-secret',
    resource: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    api_url: 'https://api.vass.va.gov',
    subscription_key: 'test-subscription-key',
    service_name: 'vass_api',
    redis_otp_expiry: 600,
    redis_session_expiry: 7200,
    redis_token_expiry: 3540,
    rate_limit_max_attempts: 5,
    rate_limit_expiry: 900,
    token_encryption_key: 'test-encryption-key-32chars-min-for-aes256-security-required'
  }.freeze

  ##
  # Stubs Settings.vass with default test configuration including encryption key.
  # Can be overridden with additional options.
  #
  # @param overrides [Hash] Optional hash to override default settings
  # @example
  #   stub_vass_settings # Uses defaults
  #   stub_vass_settings(jwt_secret: 'custom-secret') # Override specific value
  #
  def stub_vass_settings(overrides = {})
    allow(Settings).to receive(:vass).and_return(
      OpenStruct.new(DEFAULT_VASS_SETTINGS.merge(overrides))
    )
  end
end

RSpec.configure do |config|
  config.include VassSettingsHelper
end
