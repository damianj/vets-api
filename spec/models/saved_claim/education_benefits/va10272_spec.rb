# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10272 do
  let(:instance) { build(:va10272) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10272')

  describe 'retention_period' do
    it 'returns the correct period' do
      expect(instance.retention_period).to be_within(1.minute).of(60.days)
    end
  end
end
