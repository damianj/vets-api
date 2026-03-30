# frozen_string_literal: true

require 'rails_helper'
require 'bio_heart_api/form_mappers/form_21p0537_mapper'

RSpec.describe BioHeartApi::FormMappers::Form21p0537Mapper do
  let(:form_data) do
    # JSON sent from the FE gets converted to a hash with
    # snake_case keynames, so emulating that here:
    {
      'has_remarried' => true,
      'remarriage' => {
        'date_of_marriage' => { 'month' => '01', 'day' => '20', 'year' => '2020' },
        'spouse_name' => { 'first' => 'Bob', 'middle' => 'T', 'last' => 'Spouse' },
        'spouse_date_of_birth' => { 'month' => '01', 'day' => '17', 'year' => '1978' },
        'spouse_is_veteran' => true,
        'age_at_marriage' => '50',
        'spouse_ssn' => { 'first3' => '555', 'middle2' => '66', 'last4' => '7777' },
        'spouse_va_file_number' => '888888888',
        'has_terminated' => false,
        'termination_date' => { 'month' => '12', 'day' => '31', 'year' => '2023' },
        'termination_reason' => 'Divorce'
      },
      'recipient' => {
        'phone' => {
          'daytime' => { 'area_code' => '123', 'prefix' => '456', 'line_number' => '7890' },
          'evening' => { 'area_code' => '321', 'prefix' => '654', 'line_number' => '0987' }
        },
        'email' => 'jane.recipient@email.com',
        'signature' => 'Jane R Recipient',
        'signature_date' => { 'month' => '09', 'day' => '19', 'year' => '2025' }
      }
    }
  end

  describe '#call' do
    subject(:result) { described_class.new(form_data).call }

    it 'transforms form data to IBM MMS payload structure' do
      expect(result).to include(
        'SPOUSE_FIRST_NAME' => 'Bob',
        'SPOUSE_LAST_NAME' => 'Spouse',
        'FORM_TYPE' => 'VA FORM 21P-0537, DEC 2025'
      )
    end

    it 'produces expected complete payload structure' do
      # These keynames are those listed in the data dictionary from MMS
      expected_keys =
        %w[REMARRIED_AFTER_VET_DEATH_YES
           REMARRIED_AFTER_VET_DEATH_NO
           DATE_OF_MARRIAGE
           SPOUSE_NAME
           SPOUSE_FIRST_NAME
           SPOUSE_MIDDLE_INITIAL
           SPOUSE_LAST_NAME
           SPOUSE_DATE_OF_BIRTH
           SPOUSE_VET_YES
           SPOUSE_VET_NO
           VA_CLAIM_NUMBER
           SSN
           MARRIAGE_AGE
           MARR_TERM_YES
           MARR_TERM_NO
           MARR_TERM_DATE
           MARR_TERM_REASON
           DAY_PHONE
           EVENING_PHONE
           EMAIL
           SIGNATURE
           DATE_SIGNED
           FORM_TYPE]
      expect(result.keys).to match_array(expected_keys)
    end

    context 'Box 1A - Remarriage Status' do
      context 'when has remarried' do
        before { form_data['has_remarried'] = true }

        it 'checks YES and unchecks NO' do
          expect(result['REMARRIED_AFTER_VET_DEATH_YES']).to be(1)
          expect(result['REMARRIED_AFTER_VET_DEATH_NO']).to be(0)
        end
      end

      context 'when has not remarried' do
        before { form_data['has_remarried'] = false }

        it 'checks NO and unchecks YES' do
          expect(result['REMARRIED_AFTER_VET_DEATH_YES']).to be(0)
          expect(result['REMARRIED_AFTER_VET_DEATH_NO']).to be(1)
        end
      end
    end

    context 'Box 1B - Date of Marriage' do
      it 'formats date correctly' do
        expect(result['DATE_OF_MARRIAGE']).to eq('01/20/2020')
      end
    end

    context 'Box 1C - Spouse Name' do
      it 'maps spouse name fields' do
        expect(result['SPOUSE_NAME']).to eq('Bob T Spouse')
        expect(result['SPOUSE_FIRST_NAME']).to eq('Bob')
        expect(result['SPOUSE_MIDDLE_INITIAL']).to eq('T')
        expect(result['SPOUSE_LAST_NAME']).to eq('Spouse')
      end

      context 'with no middle name' do
        before { form_data['remarriage']['spouse_name'].delete('middle') }

        it 'handles missing middle initial gracefully' do
          expect(result['SPOUSE_MIDDLE_INITIAL']).to eq('')
          expect(result['SPOUSE_NAME']).to eq('Bob Spouse')
        end
      end
    end

    context 'Box 1D - Spouse Date of Birth' do
      it 'formats date correctly' do
        expect(result['SPOUSE_DATE_OF_BIRTH']).to eq('01/17/1978')
      end
    end

    context 'Box 1E - Spouse Veteran Status' do
      context 'when spouse is a veteran' do
        before { form_data['remarriage']['spouse_is_veteran'] = true }

        it 'checks YES and unchecks NO' do
          expect(result['SPOUSE_VET_YES']).to be(1)
          expect(result['SPOUSE_VET_NO']).to be(0)
        end
      end

      context 'when spouse is not a veteran' do
        before { form_data['remarriage']['spouse_is_veteran'] = false }

        it 'checks NO and unchecks YES' do
          expect(result['SPOUSE_VET_YES']).to be(0)
          expect(result['SPOUSE_VET_NO']).to be(1)
        end
      end
    end

    context 'Box 1F - Spouse Identification' do
      it 'maps VA claim number and SSN' do
        expect(result['VA_CLAIM_NUMBER']).to eq('888888888')
        expect(result['SSN']).to eq('555667777')
      end
    end

    context 'Box 1G - Marriage Age' do
      it 'maps age at marriage' do
        expect(result['MARRIAGE_AGE']).to eq('50')
      end
    end

    context 'Box 2A - Marriage Termination Status' do
      context 'when marriage has been terminated' do
        before { form_data['remarriage']['has_terminated'] = true }

        it 'checks YES and unchecks NO' do
          expect(result['MARR_TERM_YES']).to be(1)
          expect(result['MARR_TERM_NO']).to be(0)
        end
      end

      context 'when marriage has not been terminated' do
        before { form_data['remarriage']['has_terminated'] = false }

        it 'checks NO and unchecks YES' do
          expect(result['MARR_TERM_YES']).to be(0)
          expect(result['MARR_TERM_NO']).to be(1)
        end
      end
    end

    context 'Box 2B - Termination Date' do
      it 'formats date correctly' do
        expect(result['MARR_TERM_DATE']).to eq('12/31/2023')
      end
    end

    context 'Box 2C - Termination Reason' do
      it 'maps termination reason' do
        expect(result['MARR_TERM_REASON']).to eq('Divorce')
      end
    end

    context 'Box 3A/3B - Contact Phone Numbers' do
      it 'formats phone numbers correctly' do
        expect(result['DAY_PHONE']).to eq('1234567890')
        expect(result['EVENING_PHONE']).to eq('3216540987')
      end
    end

    context 'Box 4 - Email Address' do
      it 'maps email' do
        expect(result['EMAIL']).to eq('jane.recipient@email.com')
      end
    end

    context 'Box 5A/5B - Signature' do
      it 'maps signature and date' do
        expect(result['SIGNATURE']).to eq('Jane R Recipient')
        expect(result['DATE_SIGNED']).to eq('09/19/2025')
      end
    end

    context 'with minimal data' do
      let(:minimal_data) do
        {
          'has_remarried' => false,
          'recipient' => {
            'signature' => 'Jane Doe',
            'signature_date' => { 'month' => '01', 'day' => '01', 'year' => '2025' }
          }
        }
      end

      it 'handles missing remarriage data gracefully' do
        result = described_class.new(minimal_data).call
        expect(result['REMARRIED_AFTER_VET_DEATH_NO']).to be(1)
        expect(result['SPOUSE_NAME']).to eq('')
        expect(result['DATE_OF_MARRIAGE']).to eq('')
        expect(result.values).not_to include(nil)
      end
    end
  end
end
