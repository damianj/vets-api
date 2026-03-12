# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormProfiles::VA0839 do
  subject(:profile) { described_class.new(form_id: '22-0839', user:) }

  let(:user) { create(:user, icn: '123498767V234859') }

  describe '#metadata' do
    it 'returns expected metadata' do
      expect(profile.metadata).to eq({ version: 0, prefill: true, returnUrl: '/applicant/information' })
    end
  end

  describe '#prefill' do
    before do
      allow_any_instance_of(User).to(
        receive(:participant_id).and_return('600061742')
      )
    end

    it 'prefills form data' do
      VCR.use_cassette('lighthouse/direct_deposit/show/200_valid_new_icn') do
        data = profile.prefill
        expect(data[:form_data]['applicantName']).to eq({ 'first' => 'Abraham',
                                                          'last' => 'Lincoln' })
      end
    end
  end
end
