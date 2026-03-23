# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::ClaimDetailSerializer, type: :serializer do
  subject { serialize(expected_claim, serializer_class: described_class) }

  let(:evss_id) { 600_354_181 }
  let(:uuid) { '90770019-ae82-4e5a-b961-4272256ff080' }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  shared_examples 'supporting documents serialization' do |claim_type|
    let(:document) { expected_claim.supporting_documents.first }
    let(:rendered_documents) do
      if document.is_a?(Hash)
        # EVSS claim returns pre-serialized hash
        [document]
      else
        # Auto established claim returns ActiveRecord objects
        [{
          id: document.id,
          type: 'claim_supporting_document',
          md5: Digest::MD5.hexdigest(document.file_data['filename']),
          header_hash: Digest::SHA256.hexdigest(document.file_data['filename']),
          filename: document.file_data&.dig('filename'),
          uploaded_at: document.created_at
        }]
      end
    end

    it "includes :supporting_documents for #{claim_type}" do
      expect(attributes['supporting_documents'].size).to eq rendered_documents.size
    end

    it "includes :supporting_documents with attributes for #{claim_type}" do
      expect(attributes['supporting_documents'].first.keys.sort).to eq rendered_documents.first.keys.map(&:to_s).sort
    end

    it "has correct filename for #{claim_type}" do
      expect(attributes['supporting_documents'].first['filename']).to eq rendered_documents.first[:filename]
      expect(attributes['supporting_documents'].first['filename']).to eq 'custom_file_name.pdf'
    end

    it "has correct computed hashes for #{claim_type}" do
      expected_filename = document[:filename] || document.file_data&.dig('filename')
      expect(attributes['supporting_documents'].first['md5']).to eq Digest::MD5.hexdigest(expected_filename)
      expect(attributes['supporting_documents'].first['header_hash']).to eq Digest::SHA256.hexdigest(expected_filename)
    end
  end

  context 'when testing Auto Established Claims' do
    let(:expected_claim) { create(:auto_established_claim_with_supporting_documents, :established, evss_id:) }

    context 'when uuid is passed in' do
      subject { serialize(expected_claim, { serializer_class: described_class, params: { uuid: } }) }

      it 'includes :id from :uuid' do
        expect(data['id']).to eq uuid
      end
    end

    context 'when uuid is not passed in' do
      it 'includes :id from :evss_id' do
        expect(data['id']).to eq expected_claim.evss_id.to_s
      end
    end

    it 'includes :status' do
      expect(attributes['status']).to eq expected_claim.status
    end

    it 'includes :type' do
      expect(data['type']).to eq 'claims_api_claim'
    end

    it 'includes base keys' do
      base_keys = %w[
        date_filed
        min_est_date
        max_est_date
        open
        documents_needed
        development_letter_sent
        decision_letter_sent
        requested_decision
        claim_type
      ]
      expect(attributes.keys).to include(*base_keys)
    end

    include_examples 'supporting documents serialization', 'Auto Established Claim'
  end

  context 'when testing EVSS Claims' do
    let!(:auto_claim_with_docs) { create(:auto_established_claim_with_supporting_documents, :established, evss_id:) }
    let(:expected_claim) { build(:claims_api_evss_claim, evss_id:) }

    it 'includes :type' do
      expect(data['type']).to eq 'claims_api_claim'
    end

    include_examples 'supporting documents serialization', 'EVSS Claim'
  end

  context 'when comparing EVSS and Auto Established Claims' do
    let!(:auto_claim) { create(:auto_established_claim_with_supporting_documents, :established, evss_id:) }
    let(:evss_claim) { build(:claims_api_evss_claim, evss_id:) }

    it 'produces identical supporting documents serialization' do
      auto_serialized = serialize(auto_claim, serializer_class: described_class)
      evss_serialized = serialize(evss_claim, serializer_class: described_class)

      auto_data = JSON.parse(auto_serialized)['data']['attributes']['supporting_documents']
      evss_data = JSON.parse(evss_serialized)['data']['attributes']['supporting_documents']

      expect(auto_data).to eq evss_data
      expect(auto_data.first['filename']).to eq 'custom_file_name.pdf'
      expect(evss_data.first['filename']).to eq 'custom_file_name.pdf'
    end
  end
end
