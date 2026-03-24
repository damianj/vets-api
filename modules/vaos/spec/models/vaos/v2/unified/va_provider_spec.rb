# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::Unified::VAProvider do
  describe '#initialize' do
    it 'sets provider_type to va' do
      provider = described_class.new
      expect(provider.provider_type).to eq('va')
    end
  end

  describe '.from_lighthouse_facility' do
    let(:facility) do
      double(
        'FacilitiesApi::V2::Lighthouse::Facility',
        id: 'vha_983',
        unique_id: '983',
        name: 'Cheyenne VA Medical Center',
        address: {
          'physical' => {
            'address1' => '2360 East Pershing Boulevard',
            'address2' => 'Suite 100',
            'address3' => 'Building A',
            'city' => 'Cheyenne',
            'state' => 'WY',
            'zip' => '82001'
          }
        },
        phone: { 'main' => '307-778-7550' },
        lat: 41.1456,
        long: -104.7892,
        facility_type: 'va_health_facility',
        services: {
          'health' => [
            { 'serviceId' => 'primaryCare' },
            { 'serviceId' => 'audiology' }
          ]
        }
      )
    end

    it 'maps Lighthouse facility fields to VaProvider' do
      provider = described_class.from_lighthouse_facility(facility)

      expect(provider.id).to eq('983')
      expect(provider.location_id).to eq('983')
      expect(provider.name).to eq('Cheyenne VA Medical Center')
      expect(provider.provider_type).to eq('va')
      expect(provider.latitude).to eq(41.1456)
      expect(provider.longitude).to eq(-104.7892)
      expect(provider.phone).to eq('307-778-7550')
      expect(provider.distance_from_user).to be_nil
      expect(provider.facility_type).to eq('va_health_facility')
      expect(provider.schedulable_services).to eq(%w[primaryCare audiology])
      expect(provider.address).to eq({
                                       street1: '2360 East Pershing Boulevard',
                                       street2: 'Suite 100',
                                       street3: 'Building A',
                                       city: 'Cheyenne',
                                       state: 'WY',
                                       zip: '82001'
                                     })
    end

    it 'handles nil services gracefully' do
      allow(facility).to receive(:services).and_return(nil)
      provider = described_class.from_lighthouse_facility(facility)

      expect(provider.schedulable_services).to eq([])
    end

    it 'handles nil address gracefully' do
      allow(facility).to receive(:address).and_return(nil)
      provider = described_class.from_lighthouse_facility(facility)

      expect(provider.address).to be_nil
    end
  end
end
