# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

RSpec.describe 'TransformationVES', type: :request do
  let(:ves_client) { double('IvcChampva::VesApi::Client') }
  # Shared UUID injected via get_file_paths_and_metadata mock so the new
  # OHI describe blocks can assert exact application_uuid propagation.
  let(:known_form_uuid) { 'aaaabbbb-cccc-dddd-eeee-ffffaaaabbbb' }

  before do
    @original_aws_config = Aws.config.dup
    Aws.config.update(stub_responses: true)
    allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)
    allow(ves_client).to receive(:submit_1010d).with(anything, anything)
    allow(ves_client).to receive(:submit_7959c).with(anything, anything)
  end

  after do
    Aws.config = @original_aws_config
  end

  describe '#submit with flipper champva_send_to_ves enabled' do
    before do
      allow(Flipper).to receive(:enabled?)
        .with(:champva_send_to_ves, @current_user)
        .and_return(true)
    end

    it 'submits the form and verifies the transformed data going to VES' do
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
      data = JSON.parse(fixture_path.read)

      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
        .and_return(double('Record1', created_at: 1.day.ago,
                                      id: 'some_uuid', file: double(id: 'file0')))
      s3_client = instance_double(Aws::S3::Client)
      allow(s3_client).to receive(:put_object).and_return(
        double('response',
               context: double('context', http_response: double('http_response', status_code: 200)))
      )
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

      post '/ivc_champva/v1/forms', params: data
      expect(response).to have_http_status(:ok)

      # check the base attributes on the call to submit_1010d and the VesRequest object
      expect(ves_client).to have_received(:submit_1010d).with(
        anything, # transaction uuid may be auto generated per submission
        an_instance_of(IvcChampva::VesRequest).and(
          have_attributes(
            application_type: 'CHAMPVA_APPLICATION',
            application_uuid: anything, # application uuid may be auto generated per submission
            transaction_uuid: anything # transaction uuid may be auto generated per submission
          )
        )
      )

      # check the attributes on VesRequest::Sponsor
      expect(ves_client).to have_received(:submit_1010d).with(
        anything,
        an_instance_of(IvcChampva::VesRequest).and(
          have_attributes(
            sponsor: an_instance_of(IvcChampva::VesRequest::Sponsor).and(
              have_attributes(
                first_name: 'Veteran',
                last_name: 'Surname',
                middle_initial: 'B',
                suffix: nil,
                ssn: '222554444',
                va_file_number: '123456789',
                date_of_birth: '1987-02-02',
                date_of_marriage: '2005-04-06',
                is_deceased: 'true',
                date_of_death: '2021-01-08',
                is_death_on_active_service: 'true',
                phone_number: '9876543213',
                address: an_instance_of(IvcChampva::VesRequest::Address).and(
                  have_attributes(
                    street_address: '1 First Ln',
                    city: 'Place',
                    state: 'AL',
                    zip_code: '12345'
                  )
                )
              )
            )
          )
        )
      )

      # check the attributes on VesRequest::Beneficiaries item one
      expect(ves_client).to have_received(:submit_1010d).with(
        anything,
        an_instance_of(IvcChampva::VesRequest).and(
          have_attributes(
            beneficiaries: array_including(
              an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                have_attributes(
                  first_name: 'Applicant',
                  last_name: 'Onceler',
                  middle_initial: 'C',
                  suffix: nil,
                  ssn: '123456644',
                  email_address: 'email@address.com',
                  phone_number: '6543219877',
                  gender: 'FEMALE',
                  enrolled_in_medicare: true,
                  has_other_insurance: nil,
                  relationship_to_sponsor: 'SPOUSE',
                  child_type: nil,
                  date_of_birth: '1978-03-04',
                  address: an_instance_of(IvcChampva::VesRequest::Address).and(
                    have_attributes(
                      street_address: '2 Second St',
                      city: 'Town',
                      state: 'LA',
                      zip_code: '16542'
                    )
                  )
                )
              )
            )
          )
        )
      )

      # check the attributes on VesRequest::Beneficiaries item two
      expect(ves_client).to have_received(:submit_1010d).with(
        anything,
        an_instance_of(IvcChampva::VesRequest).and(
          have_attributes(
            beneficiaries: array_including(
              an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                have_attributes(
                  first_name: 'Appy',
                  last_name: 'Twos',
                  middle_initial: 'D',
                  suffix: nil,
                  ssn: '123664444',
                  email_address: 'mailme@domain.com',
                  phone_number: '2345698777',
                  gender: 'MALE',
                  enrolled_in_medicare: true,
                  has_other_insurance: true,
                  relationship_to_sponsor: 'SPOUSE',
                  child_type: nil,
                  date_of_birth: '1985-03-10',
                  address: an_instance_of(IvcChampva::VesRequest::Address).and(
                    have_attributes(
                      street_address: '3 Third Ave',
                      city: 'Ville',
                      state: 'AR',
                      zip_code: '65478'
                    )
                  )
                )
              )
            )
          )
        )
      )

      # check the attributes on VesRequest::Beneficiaries item three
      expect(ves_client).to have_received(:submit_1010d).with(
        anything,
        an_instance_of(IvcChampva::VesRequest).and(
          have_attributes(
            beneficiaries: array_including(
              an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                have_attributes(
                  first_name: 'Homer',
                  last_name: 'Simpson',
                  middle_initial: 'D',
                  suffix: nil,
                  ssn: '123664444',
                  email_address: 'mailme@homer.com',
                  phone_number: '2345698777',
                  gender: 'MALE',
                  enrolled_in_medicare: true,
                  has_other_insurance: true,
                  relationship_to_sponsor: 'SPOUSE',
                  child_type: nil,
                  date_of_birth: '1985-03-10',
                  address: an_instance_of(IvcChampva::VesRequest::Address).and(
                    have_attributes(
                      street_address: '4 Third Ave',
                      city: 'Mark',
                      state: 'AR',
                      zip_code: '65478'
                    )
                  )
                )
              )
            )
          )
        )
      )

      # check the attributes on VesRequest::Beneficiaries item four
      expect(ves_client).to have_received(:submit_1010d).with(
        anything,
        an_instance_of(IvcChampva::VesRequest).and(
          have_attributes(
            beneficiaries: array_including(
              an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                have_attributes(
                  first_name: 'Logan',
                  last_name: 'Wolf',
                  middle_initial: 'W',
                  suffix: nil,
                  ssn: '123664444',
                  email_address: 'mailme@logan.com',
                  phone_number: '2345698777',
                  gender: 'MALE',
                  enrolled_in_medicare: true,
                  has_other_insurance: true,
                  relationship_to_sponsor: 'SPOUSE',
                  child_type: nil,
                  date_of_birth: '1999-03-10',
                  address: an_instance_of(IvcChampva::VesRequest::Address).and(
                    have_attributes(
                      street_address: '426 Ave C',
                      city: 'Philadelphia',
                      state: 'PA',
                      zip_code: '65478'
                    )
                  )
                )
              )
            )
          )
        )
      )

      # check the attributes on VesRequest::Beneficiaries item five
      expect(ves_client).to have_received(:submit_1010d).with(
        anything,
        an_instance_of(IvcChampva::VesRequest).and(
          have_attributes(
            beneficiaries: array_including(
              an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                have_attributes(
                  first_name: 'Maria',
                  last_name: 'Storm',
                  middle_initial: 'W',
                  suffix: nil,
                  ssn: '123664444',
                  email_address: 'mailme@Maria.com',
                  phone_number: '2345698777',
                  gender: 'FEMALE',
                  enrolled_in_medicare: true,
                  has_other_insurance: true,
                  relationship_to_sponsor: 'SPOUSE',
                  child_type: nil,
                  date_of_birth: '1959-03-10',
                  address: an_instance_of(IvcChampva::VesRequest::Address).and(
                    have_attributes(
                      street_address: '12345 Play Place',
                      city: 'Camden',
                      state: 'NJ',
                      zip_code: '65478'
                    )
                  )
                )
              )
            )
          )
        )
      )

      # check the attributes on VesRequest::Certification
      expect(ves_client).to have_received(:submit_1010d).with(
        anything,
        an_instance_of(IvcChampva::VesRequest).and(
          have_attributes(
            certification: an_instance_of(IvcChampva::VesRequest::Certification).and(
              have_attributes(
                signature: 'GI Joe',
                signature_date: '2021-01-08',
                first_name: 'GI',
                last_name: 'Joe',
                middle_initial: 'Canceled',
                phone_number: '2345698777',
                relationship: 'Agent',
                address: an_instance_of(IvcChampva::VesRequest::Address).and(
                  have_attributes(
                    street_address: 'Hasbro',
                    city: 'Burbank',
                    state: 'CA',
                    zip_code: '90041'
                  )
                )
              )
            )
          )
        )
      )
    end

    it 'propagates form UUID to VES application_uuid' do
      captured_ves_request = nil
      allow(ves_client).to receive(:submit_1010d) do |_tx_uuid, ves_request|
        captured_ves_request = ves_request
        double('response', status: 200, body: '{}')
      end

      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
        .and_return(double('Record1', created_at: 1.day.ago,
                                      id: 'some_uuid', file: double(id: 'file0')))
      s3_client = instance_double(Aws::S3::Client)
      allow(s3_client).to receive(:put_object).and_return(
        double('response',
               context: double('context', http_response: double('http_response', status_code: 200)))
      )
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

      stored_form_uuid = nil
      allow(IvcChampvaForm).to receive(:create!) do |attrs|
        stored_form_uuid = attrs[:form_uuid]
        instance_double(IvcChampvaForm, form_uuid: stored_form_uuid, update: true)
      end

      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
      data = JSON.parse(fixture_path.read)

      post '/ivc_champva/v1/forms', params: data
      expect(response).to have_http_status(:ok)

      expect(captured_ves_request).not_to be_nil
      expect(captured_ves_request.application_uuid).to be_present
      error_msg = "Expected VES application_uuid (#{captured_ves_request.application_uuid}) " \
                  "to match stored form_uuid (#{stored_form_uuid})"
      expect(captured_ves_request.application_uuid).to eq(stored_form_uuid), error_msg
    end
  end

  # ============================================================================
  # Standalone 10-7959C OHI flow: UploadsController → format_for_ohi_request →
  # submit_7959c (once per applicant with OHI data)
  # ============================================================================
  describe '#submit for standalone 10-7959C OHI' do
    # Load the rev2025 fixture (applicants-array format) and override the single
    # existing applicant for Alice, then clone it for Bob.
    let(:standalone_ohi_data) do
      path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json',
                             'vha_10_7959c_rev2025.json')
      data = JSON.parse(path.read)
      base = data['applicants'][0]
      data.merge('applicants' => [
                   base.merge('applicant_name' => { 'first' => 'Alice', 'last' => 'Jones' },
                              'applicant_ssn' => '234234234',
                              'applicant_gender' => 'female',
                              'applicant_dob' => '1980-01-15'),
                   base.merge('applicant_name' => { 'first' => 'Bob', 'last' => 'Smith' },
                              'applicant_ssn' => '345678901',
                              'applicant_gender' => 'male',
                              'applicant_dob' => '1975-06-20')
                 ])
    end

    before do
      allow(Flipper).to receive(:enabled?).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:champva_send_7959c_to_ves, anything).and_return(true)
      allow(ves_client).to receive(:submit_7959c).and_return(double('response', status: 200, body: ''))
      allow_any_instance_of(IvcChampva::V1::UploadsController)
        .to receive(:get_file_paths_and_metadata)
        .and_return([['stub.pdf'], { 'uuid' => known_form_uuid, 'attachment_ids' => ['vha_10_7959c'] }])
      allow_any_instance_of(IvcChampva::V1::UploadsController)
        .to receive(:upload_form)
        .and_return([[200], []])
    end

    it 'calls submit_7959c once per applicant' do
      post '/ivc_champva/v1/forms', params: standalone_ohi_data

      expect(response).to have_http_status(:ok)
      expect(ves_client).to have_received(:submit_7959c).exactly(2).times
    end

    it 'propagates the form UUID as application_uuid to every OHI request' do
      captured_calls = []
      allow(ves_client).to receive(:submit_7959c) do |_tx_uuid, request|
        captured_calls << request
        double('response', status: 200, body: '')
      end

      post '/ivc_champva/v1/forms', params: standalone_ohi_data

      expect(response).to have_http_status(:ok)
      expect(captured_calls.count).to eq(2)
      captured_calls.each do |req|
        expect(req.application_uuid).to eq(known_form_uuid)
      end
    end

    it 'sends correct applicant data in each OHI request' do
      captured_calls = []
      allow(ves_client).to receive(:submit_7959c) do |_tx_uuid, request|
        captured_calls << request
        double('response', status: 200, body: '')
      end

      post '/ivc_champva/v1/forms', params: standalone_ohi_data

      expect(response).to have_http_status(:ok)
      expect(IvcChampva::VesOhiRequest::APPLICATION_TYPE).to eq('CHAMPVA_INS_APPLICATION')

      alice_req = captured_calls.find { |r| r.beneficiary_medicare.first_name == 'Alice' }
      expect(alice_req).to be_an_instance_of(IvcChampva::VesOhiRequest).and(
        have_attributes(application_uuid: known_form_uuid)
      )
      expect(alice_req.beneficiary_medicare).to have_attributes(
        first_name: 'Alice', last_name: 'Jones', ssn: '234234234', gender: 'FEMALE'
      )

      bob_req = captured_calls.find { |r| r.beneficiary_medicare.first_name == 'Bob' }
      expect(bob_req).not_to be_nil
      expect(bob_req.beneficiary_medicare).to have_attributes(
        first_name: 'Bob', last_name: 'Smith', ssn: '345678901', gender: 'MALE'
      )
    end
  end

  # ============================================================================
  # 10-10D-EXTENDED flow: UploadsController → format_for_extended_request →
  # submit_1010d (parent) + submit_7959c (one per applicant with OHI data).
  # All three requests must share the same application_uuid and each must have
  # a distinct transaction_uuid.
  # ============================================================================
  describe '#submit for 10-10D-EXTENDED with OHI subforms' do
    # Minimal inline payload — the full fixture has nested file attachment hashes
    # at multiple levels that cause Rails form encoding to drop scalar sibling
    # fields (e.g. 'provider'), failing VES "insuranceName" validation.
    let(:extended_ohi_data) do
      {
        'form_number' => '10-10D-EXTENDED',
        'veteran' => {
          'full_name' => { 'first' => 'Veteran', 'last' => 'Sponsor' },
          'ssn_or_tin' => '123456789',
          'date_of_birth' => '1960-01-01',
          'address' => { 'street_combined' => '1 Sponsor Lane', 'city' => 'Townsburg',
                         'state' => 'VA', 'postal_code' => '22222' },
          'sponsor_is_deceased' => false
        },
        'applicants' => [
          {
            'applicant_name' => { 'first' => 'Johnny', 'last' => 'Alvin' },
            'ssn_or_tin' => '345345345',
            'applicant_address' => { 'country' => 'USA', 'street_combined' => '456 Circle St',
                                     'city' => 'Clinton', 'state' => 'VA', 'postal_code' => '56789' },
            'applicant_gender' => { 'gender' => 'male' },
            'applicant_dob' => '2000-01-01',
            'vet_relationship' => 'CHILD',
            'applicant_relationship_origin' => { 'relationship_to_veteran' => 'blood' },
            'health_insurance' => [{ 'insurance_type' => 'medigap', 'provider' => 'Blue Cross',
                                     'effective_date' => '2024-10-01',
                                     'expiration_date' => '2024-10-02' }]
          },
          {
            'applicant_name' => { 'first' => 'Jane', 'last' => 'Doe' },
            'ssn_or_tin' => '987654321',
            'applicant_address' => { 'country' => 'USA', 'street_combined' => '789 Oak Ave',
                                     'city' => 'Townville', 'state' => 'CA', 'postal_code' => '90210' },
            'applicant_gender' => { 'gender' => 'female' },
            'applicant_dob' => '1990-05-15',
            'vet_relationship' => 'SPOUSE',
            'applicant_relationship_origin' => { 'relationship_to_veteran' => 'married' },
            'medicare' => [{ 'medicare_part_a_effective_date' => '2022-03-01',
                             'medicare_part_b_effective_date' => '2022-03-01' }]
          }
        ],
        'certification' => { 'date' => '2024-12-01', 'first_name' => 'Certifier', 'last_name' => 'Jones',
                             'phone_number' => '1231231234', 'relationship' => 'other' },
        'statement_of_truth_signature' => 'Certifier Jones'
      }
    end

    before do
      allow(Flipper).to receive(:enabled?).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:champva_send_to_ves, anything).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:champva_send_7959c_to_ves, anything).and_return(true)
      # submit_1010d must return 200 so submit_to_ves proceeds to subforms;
      # body must be stubbed since update_ves_records accesses it on non-200 responses.
      allow(ves_client).to receive_messages(submit_1010d: double('response', status: 200, body: ''),
                                            submit_7959c: double(
                                              'response', status: 200, body: ''
                                            ))
      allow_any_instance_of(IvcChampva::V1::UploadsController)
        .to receive(:get_file_paths_and_metadata)
        .and_return([['stub.pdf'], { 'uuid' => known_form_uuid, 'attachment_ids' => ['vha_10_10d'] }])
      allow_any_instance_of(IvcChampva::V1::UploadsController)
        .to receive(:upload_form)
        .and_return([[200], []])
    end

    it 'submits the 10-10D parent and one OHI subform request per applicant' do
      post '/ivc_champva/v1/forms', params: extended_ohi_data

      expect(response).to have_http_status(:ok)
      expect(ves_client).to have_received(:submit_1010d).once
      expect(ves_client).to have_received(:submit_7959c).twice
    end

    it 'propagates the form UUID as application_uuid to the parent and every subform' do
      captured_1010d = []
      captured_7959c = []
      allow(ves_client).to receive(:submit_1010d) do |_tx, req|
        captured_1010d << req
        double('response', status: 200, body: '')
      end
      allow(ves_client).to receive(:submit_7959c) do |_tx, req|
        captured_7959c << req
        double('response', status: 200, body: '')
      end

      post '/ivc_champva/v1/forms', params: extended_ohi_data

      expect(response).to have_http_status(:ok)
      expect(captured_1010d.first.application_uuid).to eq(known_form_uuid)
      captured_7959c.each { |req| expect(req.application_uuid).to eq(known_form_uuid) }
    end

    it 'uses a distinct transaction_uuid for the parent and each subform' do
      tx_uuids = []
      allow(ves_client).to receive(:submit_1010d) do |tx, _req|
        tx_uuids << tx
        double('response', status: 200, body: '')
      end
      allow(ves_client).to receive(:submit_7959c) do |tx, _req|
        tx_uuids << tx
        double('response', status: 200, body: '')
      end

      post '/ivc_champva/v1/forms', params: extended_ohi_data

      expect(response).to have_http_status(:ok)
      expect(tx_uuids.count).to eq(3)
      expect(tx_uuids.uniq.count).to eq(3),
                                     'Each VES submission (parent + 2 subforms) must have a unique transaction_uuid'
    end

    it 'sends correct sponsor and beneficiary data in the parent 10-10D request' do
      captured_parent = nil
      allow(ves_client).to receive(:submit_1010d) do |_tx, req|
        captured_parent = req
        double('response', status: 200, body: '')
      end

      post '/ivc_champva/v1/forms', params: extended_ohi_data

      expect(response).to have_http_status(:ok)
      expect(captured_parent).to be_an_instance_of(IvcChampva::VesRequest).and(
        have_attributes(application_uuid: known_form_uuid, application_type: 'CHAMPVA_APPLICATION')
      )
      expect(captured_parent.sponsor).to have_attributes(
        first_name: 'Veteran', last_name: 'Sponsor', ssn: '123456789'
      )
      expect(captured_parent.beneficiaries.map(&:first_name)).to contain_exactly('Johnny', 'Jane')
    end

    it 'sends correct OHI beneficiary data in each subform request' do
      captured_subforms = []
      allow(ves_client).to receive(:submit_7959c) do |_tx, req|
        captured_subforms << req
        double('response', status: 200, body: '')
      end

      post '/ivc_champva/v1/forms', params: extended_ohi_data

      expect(response).to have_http_status(:ok)
      expect(captured_subforms.map { |r| r.beneficiary_medicare.first_name })
        .to contain_exactly('Johnny', 'Jane')

      johnny_req = captured_subforms.find { |r| r.beneficiary_medicare.first_name == 'Johnny' }
      expect(johnny_req).to be_an_instance_of(IvcChampva::VesOhiRequest).and(
        have_attributes(application_uuid: known_form_uuid)
      )
      expect(johnny_req.beneficiary_medicare).to have_attributes(
        last_name: 'Alvin', ssn: '345345345', gender: 'MALE'
      )

      jane_req = captured_subforms.find { |r| r.beneficiary_medicare.first_name == 'Jane' }
      expect(jane_req.beneficiary_medicare).to have_attributes(
        last_name: 'Doe', ssn: '987654321', gender: 'FEMALE'
      )
    end

    it 'does not submit subforms when the parent 10-10D request fails' do
      # update_ves_records calls ves_response.body when status != 200
      allow(ves_client).to receive(:submit_1010d)
        .and_return(double('response', status: 500, body: 'VES server error'))

      post '/ivc_champva/v1/forms', params: extended_ohi_data

      expect(response).to have_http_status(:ok)
      expect(ves_client).not_to have_received(:submit_7959c)
    end

    it 'propagates form UUID to VES application_uuid' do
      # Capture the actual VES request to verify UUID propagation
      captured_ves_request = nil
      allow(ves_client).to receive(:submit_1010d) do |_tx_uuid, ves_request|
        captured_ves_request = ves_request
        double('response', status: 200, body: '{}')
      end

      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
        .and_return(double('Record1', created_at: 1.day.ago,
                                      id: 'some_uuid', file: double(id: 'file0')))
      s3_client = instance_double(Aws::S3::Client)
      allow(s3_client).to receive(:put_object).and_return(
        double('response',
               context: double('context', http_response: double('http_response', status_code: 200)))
      )
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

      # Track the form UUID that gets stored in the database
      stored_form_uuid = nil
      allow(IvcChampvaForm).to receive(:create!) do |attrs|
        stored_form_uuid = attrs[:form_uuid]
        instance_double(IvcChampvaForm,
                        form_uuid: stored_form_uuid,
                        update: true)
      end

      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
      data = JSON.parse(fixture_path.read)

      post '/ivc_champva/v1/forms', params: data
      expect(response).to have_http_status(:ok)

      # Verify the VES request's application_uuid matches the form's UUID
      expect(captured_ves_request).not_to be_nil
      expect(captured_ves_request.application_uuid).to be_present
      error_msg = "Expected VES application_uuid (#{captured_ves_request.application_uuid}) " \
                  "to match stored form_uuid (#{stored_form_uuid})"
      expect(captured_ves_request.application_uuid).to eq(stored_form_uuid), error_msg
    end
  end
end
