# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::Poa2122ServiceHelpers do
  subject(:helper) { dummy_class.new }

  let(:dummy_class) do
    Class.new do
      include AccreditedRepresentativePortal::Poa2122ServiceHelpers
    end
  end

  describe '#normalize_codes' do
    it 'normalizes a single string' do
      expect(helper.normalize_codes('ABC')).to eq(['ABC'])
    end

    it 'splits comma separated values' do
      expect(helper.normalize_codes('ABC, DEF')).to eq(%w[ABC DEF])
    end

    it 'handles arrays and removes blanks' do
      input = ['ABC', ' DEF ', '', nil]
      expect(helper.normalize_codes(input)).to eq(%w[ABC DEF])
    end

    it 'deduplicates values' do
      input = %w[ABC ABC DEF]
      expect(helper.normalize_codes(input)).to eq(%w[ABC DEF])
    end

    it 'flattens nested arrays and comma separated values' do
      input = ['ABC, DEF', %w[GHI ABC]]
      expect(helper.normalize_codes(input)).to eq(%w[ABC DEF GHI])
    end
  end

  describe '#organizations_for' do
    it 'returns organizations matching POA codes' do
      org = create(:veteran_organization, poa: 'ABC')
      create(:veteran_organization, poa: 'DEF')

      result = helper.organizations_for(['ABC'])

      expect(result).to contain_exactly(org)
    end
  end

  describe '#set_active_reps_mode!' do
    let!(:organization) { create(:veteran_organization, poa: 'ABC') }

    let!(:rep1) do
      create(
        :veteran_organization_representative,
        organization:,
        acceptance_mode: 'any_request',
        deactivated_at: nil
      )
    end

    let!(:rep2) do
      create(
        :veteran_organization_representative,
        organization:,
        acceptance_mode: 'any_request',
        deactivated_at: nil
      )
    end

    it 'updates acceptance_mode for active reps' do
      org_scope = Veteran::Service::Organization.where(poa: organization.poa)

      updated = helper.set_active_reps_mode!(org_scope, 'self_only')

      expect(updated).to eq(2)
      expect(rep1.reload.acceptance_mode).to eq('self_only')
      expect(rep2.reload.acceptance_mode).to eq('self_only')
    end

    context 'when update count does not match expected' do
      let(:active_scope) { double('active_scope') }
      let(:where_scope) { double('where_scope') }

      before do
        allow(Veteran::Service::OrganizationRepresentative)
          .to receive(:active)
          .and_return(active_scope)

        allow(where_scope).to receive_messages(where: where_scope, not: active_scope)
        allow(active_scope).to receive_messages(where: where_scope, count: 2, update_all: 1)
      end

      it 'raises MismatchError when updated count differs from expected count' do
        org_scope = Veteran::Service::Organization.where(poa: organization.poa)

        expect do
          helper.set_active_reps_mode!(org_scope, 'self_only')
        end.to raise_error(
          AccreditedRepresentativePortal::Poa2122ServiceHelpers::MismatchError,
          /expected 2 reps, updated 1/
        )
      end
    end
  end
end
