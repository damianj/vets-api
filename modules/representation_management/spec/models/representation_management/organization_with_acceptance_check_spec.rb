# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::OrganizationWithAcceptanceCheck do
  subject { described_class.new(organization, eligible_poas:) }

  let(:organization) { create(:organization, poa: 'ABC', can_accept_digital_poa_requests: true) }
  let(:eligible_poas) { described_class.eligible_poas_for([organization]) }

  describe '#can_accept_digital_poa_requests' do
    context 'when the organization cannot accept digital POA requests' do
      let(:organization) { create(:organization, poa: 'ABC', can_accept_digital_poa_requests: false) }

      it 'returns false' do
        expect(subject.can_accept_digital_poa_requests).to be false
      end
    end

    context 'when the organization can accept digital POA requests' do
      let(:representative) { create(:representative, representative_id: '12345') }

      context 'when no organization_representative records exist' do
        it 'returns false' do
          expect(subject.can_accept_digital_poa_requests).to be false
        end
      end

      context 'when an active organization_representative has acceptance_mode any_request' do
        before do
          create(:veteran_organization_representative,
                 representative:,
                 organization:,
                 acceptance_mode: 'any_request')
        end

        it 'returns true' do
          expect(subject.can_accept_digital_poa_requests).to be true
        end
      end

      context 'when organization_representative has acceptance_mode self_only' do
        before do
          create(:veteran_organization_representative,
                 representative:,
                 organization:,
                 acceptance_mode: 'self_only')
        end

        it 'returns false' do
          expect(subject.can_accept_digital_poa_requests).to be false
        end
      end

      context 'when the only any_request organization_representative is deactivated' do
        before do
          create(:veteran_organization_representative,
                 representative:,
                 organization:,
                 acceptance_mode: 'any_request',
                 deactivated_at: Time.current)
        end

        it 'returns false' do
          expect(subject.can_accept_digital_poa_requests).to be false
        end
      end
    end
  end

  describe '.eligible_poas_for' do
    let(:representative) { create(:representative, representative_id: '12345') }

    it 'returns a set of POAs with active any_request reps' do
      create(:veteran_organization_representative,
             representative:,
             organization:,
             acceptance_mode: 'any_request')

      result = described_class.eligible_poas_for([organization])
      expect(result).to be_a(Set)
      expect(result).to include('ABC')
    end

    it 'excludes POAs without any_request reps' do
      create(:veteran_organization_representative,
             representative:,
             organization:,
             acceptance_mode: 'self_only')

      result = described_class.eligible_poas_for([organization])
      expect(result).not_to include('ABC')
    end
  end

  it 'delegates other methods to the organization' do
    expect(subject.poa).to eq('ABC')
    expect(subject.name).to eq(organization.name)
  end
end
