# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_ptcpnt_phone_service'

describe ClaimsApi::VnpPtcpntPhoneService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_ptcpnt_phone_create' do
    let(:options) { {} }

    it 'responds with attributes' do
      options[:vnp_proc_id] = '29798'
      options[:vnp_ptcpnt_id] = '44693'
      options[:cntry_nbr] = nil
      options[:phone_nbr] = '2225552252'
      options[:frgn_phone_rfrnc_txt] = nil
      options[:efctv_dt] = '2020-07-16T18:20:17Z'

      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_phone_service/vnp_ptcpnt_phone_create') do
        response = subject.vnp_ptcpnt_phone_create(options)

        expect(response[:vnp_proc_id]).to eq '29798'
        expect(response[:vnp_ptcpnt_id]).to eq '44693'
        expect(response[:phone_type_nm]).to eq 'Daytime'
        expect(response[:phone_nbr]).to eq '2225552252'
        expect(response[:frgn_phone_rfrnc_txt]).to be_nil
        expect(response[:cntry_nbr]).to be_nil
        expect(response[:efctv_dt]).to eq '2020-07-16T18:20:17Z'
        expect(response[:vnp_ptcpnt_phone_id]).to eq '116005'
      end
    end

    it 'responds with attributes for international phone number' do
      options[:vnp_proc_id] = '3914707'
      options[:vnp_ptcpnt_id] = '249264'
      options[:cntry_nbr] = '22'
      options[:phone_nbr] = ' '
      options[:frgn_phone_rfrnc_txt] = '446666-7777'
      options[:efctv_dt] = '2026-03-09T16:23:40Z'

      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_phone_service/vnp_ptcpnt_phone_create_international') do
        response = subject.vnp_ptcpnt_phone_create(options)

        expect(response[:vnp_proc_id]).to eq '3914707'
        expect(response[:vnp_ptcpnt_id]).to eq '249264'
        expect(response[:phone_type_nm]).to eq 'Daytime'
        expect(response[:phone_nbr]).to eq(' ')
        expect(response[:frgn_phone_rfrnc_txt]).to eq('446666-7777')
        expect(response[:cntry_nbr]).to eq('22')
        expect(response[:efctv_dt]).to eq '2026-03-09T16:23:40Z'
        expect(response[:vnp_ptcpnt_phone_id]).to eq '116011'
      end
    end

    it 'responds appropriately with invalid options' do
      options[:vnp_proc_id] = 'not-an-id'
      options[:vnp_ptcpnt_id] = nil
      options[:phone_nbr] = '2225552252'
      options[:efctv_dt] = '2020-07-16T18:20:17Z'

      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_phone_service/invalid_vnp_ptcpnt_phone_create') do
        expect do
          subject.vnp_ptcpnt_phone_create(options)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end

  describe 'vnp_ptcpnt_phone_find_by_primary_key' do
    context 'domestic' do
      let(:primary_id) { '111642' }

      it 'responds when sent valid params' do
        VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_phone_service/valid_vnp_ptcpnt_phone_find_by_primary_key') do
          response = subject.vnp_ptcpnt_phone_find_by_primary_key(id: primary_id)

          expect(response).to include(
            {
              phone_nbr: '5555559876'
            }
          )
        end
      end
    end

    context 'international' do
      let(:primary_id) { '116008' }

      it 'responds when sent valid params' do
        recording = 'claims_api/bgs/vnp_ptcpnt_phone_service/valid_vnp_ptcpnt_phone_find_by_primary_key_international'
        VCR.use_cassette(recording) do
          response = subject.vnp_ptcpnt_phone_find_by_primary_key(id: primary_id)

          expect(response).to include(
            {
              phone_nbr: ' ',
              cntry_nbr: '22',
              frgn_phone_rfrnc_txt: '446666-7777'
            }
          )
        end
      end
    end
  end
end
