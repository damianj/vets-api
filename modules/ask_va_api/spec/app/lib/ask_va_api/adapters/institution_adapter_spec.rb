# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Adapters::InstitutionAdapter do
  describe '.search' do
    it 'adds physical_state and physical_zip to each institution' do
      institutions = {
        data: [
          { attributes: { facility_code: '123', name: 'Test University', state: 'IL' } }
        ]
      }

      result = described_class.search(institutions)

      attrs = result[:data].first[:attributes]
      expect(attrs[:physical_state]).to eq('IL')
      expect(attrs[:physical_zip]).to eq('')
    end

    it 'defaults physical_state to empty string when state is nil' do
      institutions = {
        data: [
          { attributes: { facility_code: '456', name: 'Another College', state: nil } }
        ]
      }

      result = described_class.search(institutions)

      attrs = result[:data].first[:attributes]
      expect(attrs[:physical_state]).to eq('')
      expect(attrs[:physical_zip]).to eq('')
    end

    it 'sets physical_zip to empty string because v1 endpoint does not provide a zip equivalent' do
      institutions = {
        data: [
          { attributes: { facility_code: '789', name: 'Zip College', state: 'TX' } }
        ]
      }

      result = described_class.search(institutions)

      attrs = result[:data].first[:attributes]
      expect(attrs[:physical_zip]).to eq('')
    end

    it 'handles multiple institutions' do
      institutions = {
        data: [
          { attributes: { facility_code: '1', name: 'School A', state: 'CA' } },
          { attributes: { facility_code: '2', name: 'School B', state: nil } }
        ]
      }

      result = described_class.search(institutions)

      expect(result[:data][0][:attributes][:physical_state]).to eq('CA')
      expect(result[:data][0][:attributes][:physical_zip]).to eq('')
      expect(result[:data][1][:attributes][:physical_state]).to eq('')
      expect(result[:data][1][:attributes][:physical_zip]).to eq('')
    end
  end

  describe '.details' do
    it 'overrides physical_zip with empty string' do
      institution_detail = {
        data: {
          attributes: {
            facility_code: '123', name: 'Test University',
            physical_state: 'IL', physical_zip: '61820'
          }
        }
      }

      result = described_class.details(institution_detail)

      expect(result[:data][:attributes][:physical_zip]).to eq('')
      expect(result[:data][:attributes][:physical_state]).to eq('IL')
    end
  end
end
