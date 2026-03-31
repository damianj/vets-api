# frozen_string_literal: true

require 'rails_helper'
require 'mhv_ac/configuration'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe MHVAC::Configuration do
  let(:service_config) { described_class.instance }

  describe '#app_token', skip: 'Disabling flakey spec' do
    it 'returns the app token from settings' do
      allow(Settings.mhv.rx).to receive(:app_token).and_return('test_token')
      expect(service_config.app_token).to eq('test_token')
    end
  end

  describe '#x_api_key' do
    it 'returns the API GW key from settings', skip: 'Disabling flakey spec' do
      allow(Settings.mhv.rx).to receive(:x_api_key).and_return('test_api_key')
      expect(service_config.x_api_key).to eq('test_api_key')
    end
  end

  describe '#service_name', skip: 'Disabling flakey spec' do
    it 'returns the service name' do
      expect(service_config.service_name).to eq('MHVAcctCreation')
    end
  end

  describe '#breakers_error_threshold', skip: 'Disabling flakey spec' do
    it 'returns the error threshold for breakers' do
      expect(service_config.breakers_error_threshold).to eq(50)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
