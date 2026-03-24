# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::Unified::EpsProvider do
  describe '#initialize' do
    it 'sets provider_type to community_care' do
      provider = described_class.new
      expect(provider.provider_type).to eq('community_care')
    end
  end

  describe '.from_eps_provider_service' do
    let(:eps_provider) do
      {
        id: '9mN718pH',
        name: 'Dr. Bones @ FHA South Melbourne Medical Complex',
        individual_providers: [
          { name: 'Dr. Bones', npi: '91560381x' }
        ],
        provider_organization: { name: 'Meridian Health' },
        location: {
          name: 'FHA South Melbourne Medical Complex',
          address: '1105 Palmetto Ave, Melbourne, FL, 32901, US',
          latitude: 28.08061,
          longitude: -80.60322,
          timezone: 'America/New_York'
        },
        network_ids: ['sandboxnetwork-5vuTac8v'],
        contact_details: [
          { system: 'phone', use: 'for_patient', value: '555-555-0001' }
        ],
        specialties: [
          { id: '208800000X', name: 'Urology' }
        ],
        features: {
          is_digital: true,
          direct_booking: { is_enabled: true }
        }
      }
    end

    it 'maps EPS provider fields to EpsProvider' do
      provider = described_class.from_eps_provider_service(eps_provider)

      expect(provider.id).to eq('9mN718pH')
      expect(provider.provider_service_id).to eq('9mN718pH')
      expect(provider.name).to eq('Dr. Bones @ FHA South Melbourne Medical Complex')
      expect(provider.provider_type).to eq('community_care')
      expect(provider.latitude).to eq(28.08061)
      expect(provider.longitude).to eq(-80.60322)
      expect(provider.phone).to eq('555-555-0001')
      expect(provider.npi).to eq('91560381x')
      expect(provider.network_id).to eq('sandboxnetwork-5vuTac8v')
      expect(provider.specialties).to eq([{ id: '208800000X', name: 'Urology' }])
      expect(provider.schedulable_services).to eq(['Urology'])
      expect(provider.address).to eq({
                                       street1: '1105 Palmetto Ave',
                                       city: 'Melbourne',
                                       state: 'FL',
                                       zip: '32901'
                                     })
    end

    it 'works with OpenStruct input' do
      provider = described_class.from_eps_provider_service(OpenStruct.new(eps_provider))

      expect(provider.id).to eq('9mN718pH')
      expect(provider.provider_type).to eq('community_care')
    end

    it 'handles missing contact details' do
      eps_provider[:contact_details] = nil
      provider = described_class.from_eps_provider_service(eps_provider)

      expect(provider.phone).to be_nil
    end

    it 'handles missing individual providers' do
      eps_provider[:individual_providers] = nil
      provider = described_class.from_eps_provider_service(eps_provider)

      expect(provider.npi).to be_nil
    end
  end
end
