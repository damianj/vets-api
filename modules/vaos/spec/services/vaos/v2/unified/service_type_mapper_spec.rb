# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::Unified::ServiceTypeMapper do
  describe '.to_vaos' do
    context 'with exact-match Lighthouse service IDs' do
      {
        'primaryCare' => 'primaryCare',
        'audiology' => 'audiology',
        'optometry' => 'optometry',
        'ophthalmology' => 'ophthalmology',
        'socialWork' => 'socialWork'
      }.each do |lighthouse_id, vaos_id|
        it "maps '#{lighthouse_id}' to '#{vaos_id}'" do
          expect(described_class.to_vaos(lighthouse_id)).to eq(vaos_id)
        end
      end
    end

    context 'with semantic-match Lighthouse service IDs' do
      {
        'mentalHealth' => 'outpatientMentalHealth',
        'nutrition' => 'foodAndNutrition',
        'covid19Vaccine' => 'covid',
        'sleepMedicine' => 'homeSleepTesting',
        'weightManagement' => 'moveProgram',
        'pharmacy' => 'clinicalPharmacyPrimaryCare'
      }.each do |lighthouse_id, vaos_id|
        it "maps '#{lighthouse_id}' to '#{vaos_id}'" do
          expect(described_class.to_vaos(lighthouse_id)).to eq(vaos_id)
        end
      end
    end

    context 'with Lighthouse service IDs that have no VAOS equivalent' do
      %w[cardiology dermatology dental gastroenterology laboratory podiatry radiology].each do |lighthouse_id|
        it "returns nil for '#{lighthouse_id}'" do
          expect(described_class.to_vaos(lighthouse_id)).to be_nil
        end
      end
    end

    it 'returns nil for an unknown service ID' do
      expect(described_class.to_vaos('nonexistentService')).to be_nil
    end

    it 'returns nil for nil input' do
      expect(described_class.to_vaos(nil)).to be_nil
    end

    context 'with PascalCase serviceId (first character only uppercase)' do
      it "maps 'Optometry' to 'optometry' per facilities_api serializer fixture casing" do
        expect(described_class.to_vaos('Optometry')).to eq('optometry')
      end

      it "maps 'Ophthalmology' to 'ophthalmology'" do
        expect(described_class.to_vaos('Ophthalmology')).to eq('ophthalmology')
      end

      it 'still maps lowerCamelCase primaryCare correctly (full downcase would break this)' do
        expect(described_class.to_vaos('primaryCare')).to eq('primaryCare')
      end
    end
  end

  describe '.schedulable_services' do
    it 'returns mapped VAOS service types from Lighthouse health services' do
      lighthouse_services = [
        { 'serviceId' => 'primaryCare', 'name' => 'Primary care' },
        { 'serviceId' => 'audiology', 'name' => 'Audiology and speech' },
        { 'serviceId' => 'mentalHealth', 'name' => 'Mental health care' }
      ]

      result = described_class.schedulable_services(lighthouse_services)

      expect(result).to contain_exactly('primaryCare', 'audiology', 'outpatientMentalHealth')
    end

    it 'excludes Lighthouse services with no VAOS equivalent' do
      lighthouse_services = [
        { 'serviceId' => 'primaryCare', 'name' => 'Primary care' },
        { 'serviceId' => 'cardiology', 'name' => 'Cardiology' },
        { 'serviceId' => 'dermatology', 'name' => 'Dermatology' }
      ]

      result = described_class.schedulable_services(lighthouse_services)

      expect(result).to eq(['primaryCare'])
    end

    it 'returns unique values when duplicates would result' do
      lighthouse_services = [
        { 'serviceId' => 'primaryCare', 'name' => 'Primary care' },
        { 'serviceId' => 'primaryCare', 'name' => 'Primary care duplicate' }
      ]

      result = described_class.schedulable_services(lighthouse_services)

      expect(result).to eq(['primaryCare'])
    end

    it 'maps PascalCase serviceId in health array (e.g. Optometry from Lighthouse)' do
      lighthouse_services = [
        { 'serviceId' => 'Optometry', 'name' => 'Optometry' },
        { 'serviceId' => 'cardiology', 'name' => 'Cardiology' }
      ]

      result = described_class.schedulable_services(lighthouse_services)

      expect(result).to eq(['optometry'])
    end

    it 'returns an empty array when no services map to VAOS types' do
      lighthouse_services = [
        { 'serviceId' => 'cardiology', 'name' => 'Cardiology' },
        { 'serviceId' => 'dental', 'name' => 'Dental' }
      ]

      result = described_class.schedulable_services(lighthouse_services)

      expect(result).to eq([])
    end

    it 'returns an empty array for empty input' do
      expect(described_class.schedulable_services([])).to eq([])
    end

    it 'returns an empty array for nil input' do
      expect(described_class.schedulable_services(nil)).to eq([])
    end
  end

  describe 'LIGHTHOUSE_TO_VAOS constant' do
    it 'maps only to values present in SCHEDULABLE_SERVICE_TYPES' do
      schedulable = VAOS::V2::AppointmentsService::SCHEDULABLE_SERVICE_TYPES

      described_class::LIGHTHOUSE_TO_VAOS.each_value do |vaos_type|
        expect(schedulable).to include(vaos_type),
                               "Mapped VAOS type '#{vaos_type}' is not in SCHEDULABLE_SERVICE_TYPES"
      end
    end

    it 'is frozen' do
      expect(described_class::LIGHTHOUSE_TO_VAOS).to be_frozen
    end
  end
end
