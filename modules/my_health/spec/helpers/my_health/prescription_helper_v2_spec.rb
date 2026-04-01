# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/vista_prescription_adapter'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'

RSpec.describe MyHealth::PrescriptionHelperV2 do
  let(:helper_class) do
    Class.new do
      include MyHealth::PrescriptionHelperV2::Filtering
      include MyHealth::PrescriptionHelperV2::Sorting

      attr_accessor :current_user

      def initialize
        @current_user = nil
      end
    end
  end

  let(:helper) { helper_class.new }

  def build_prescription(attrs = {})
    defaults = {
      id: SecureRandom.uuid,
      prescription_name: 'Test Med',
      disp_status: 'Active',
      is_refillable: false,
      is_renewable: false,
      is_trackable: false,
      dispensed_date: nil,
      station_number: '123',
      prescription_source: 'VA',
      dispenses: []
    }
    merged = defaults.merge(attrs)
    merged[:id] = attrs[:prescription_id] if attrs.key?(:prescription_id)
    OpenStruct.new(merged)
  end

  # Helper to create a resource-like object for sorting tests
  def build_resource(records)
    OpenStruct.new(records:, metadata: {})
  end

  describe 'MyHealth::PrescriptionHelperV2::Filtering' do
    describe '#filter_data_by_refill_and_renew' do
      it 'includes items that are refillable' do
        refillable_item = build_prescription(is_refillable: true, refill_remaining: 3)
        non_refillable_item = build_prescription(is_refillable: false, disp_status: 'Discontinued')
        data = [refillable_item, non_refillable_item]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to include(refillable_item)
        expect(result).not_to include(non_refillable_item)
      end

      it 'includes items that are renewable (is_renewable: true)' do
        renewable_item = build_prescription(is_renewable: true, is_refillable: false)
        non_renewable_item = build_prescription(is_renewable: false, is_refillable: false)
        data = [renewable_item, non_renewable_item]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to include(renewable_item)
        expect(result).not_to include(non_renewable_item)
      end

      it 'includes items that are both refillable and renewable' do
        both_item = build_prescription(is_refillable: true, is_renewable: true)
        data = [both_item]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to include(both_item)
      end

      it 'excludes items that are neither refillable nor renewable' do
        neither_item = build_prescription(is_refillable: false, is_renewable: false)
        data = [neither_item]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to be_empty
      end

      it 'returns empty array for empty input' do
        result = helper.filter_data_by_refill_and_renew([])
        expect(result).to eq([])
      end

      it 'handles mixed collection correctly' do
        refillable = build_prescription(is_refillable: true, is_renewable: false)
        renewable = build_prescription(is_refillable: false, is_renewable: true)
        neither = build_prescription(is_refillable: false, is_renewable: false)
        data = [refillable, renewable, neither]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result.length).to eq(2)
        expect(result).to include(refillable, renewable)
        expect(result).not_to include(neither)
      end
    end

    describe '#renewable' do
      it 'returns true when is_renewable is true' do
        prescription = build_prescription(is_renewable: true)
        expect(helper.renewable(prescription)).to be true
      end

      it 'returns false when is_renewable is false' do
        prescription = build_prescription(is_renewable: false)
        expect(helper.renewable(prescription)).to be false
      end

      it 'returns false when is_renewable is nil' do
        prescription = build_prescription(is_renewable: nil)
        expect(helper.renewable(prescription)).to be false
      end

      it 'returns false when item does not respond to is_renewable' do
        item = OpenStruct.new(id: '1')
        expect(helper.renewable(item)).to be false
      end
    end
  end

  describe 'MyHealth::PrescriptionHelperV2::Sorting' do
    let(:helper_class) do
      Class.new do
        include MyHealth::PrescriptionHelperV2::Sorting
      end
    end
    let(:helper) { helper_class.new }

    describe '#apply_sorting' do
      let(:prescription1) do
        double('prescription1',
               prescription_name: 'Zoloft',
               disp_status: 'Active',
               dispensed_date: Date.new(2024, 1, 1),
               prescription_source: 'VA',
               dispenses: [],
               orderable_item: nil)
      end

      let(:prescription2) do
        double('prescription2',
               prescription_name: 'Aspirin',
               disp_status: 'Active',
               dispensed_date: Date.new(2024, 3, 1),
               prescription_source: 'VA',
               dispenses: [],
               orderable_item: nil)
      end

      let(:prescription3) do
        double('prescription3',
               prescription_name: 'Metformin',
               disp_status: 'Inactive',
               dispensed_date: Date.new(2024, 2, 1),
               prescription_source: 'VA',
               dispenses: [],
               orderable_item: nil)
      end

      let(:prescriptions) { [prescription1, prescription2, prescription3] }

      let(:resource) do
        records = prescriptions.dup
        metadata = {}
        double('resource').tap do |r|
          allow(r).to receive_messages(records:, metadata:)
          allow(r).to receive(:records=) { |new_records| records.replace(new_records) }
          allow(r).to receive(:metadata=) { |new_metadata| metadata.replace(new_metadata) }
        end
      end

      before do
        allow(prescription1).to receive(:respond_to?).with(:dispenses).and_return(true)
        allow(prescription1).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)
        allow(prescription2).to receive(:respond_to?).with(:dispenses).and_return(true)
        allow(prescription2).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)
        allow(prescription3).to receive(:respond_to?).with(:dispenses).and_return(true)
        allow(prescription3).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)
      end

      context 'when sort_param is nil' do
        it 'applies default sorting' do
          result = helper.apply_sorting(resource, nil)

          expect(result.metadata[:sort]).to eq({
                                                 'disp_status' => 'ASC',
                                                 'prescription_name' => 'ASC',
                                                 'dispensed_date' => 'DESC'
                                               })
        end
      end

      context 'when sort_param is alphabetical-rx-name' do
        it 'sorts by prescription_name ascending with secondary sort by dispensed_date descending' do
          result = helper.apply_sorting(resource, 'alphabetical-rx-name')

          expect(result.metadata[:sort]).to eq({
                                                 'prescription_name' => 'ASC',
                                                 'dispensed_date' => 'DESC'
                                               })
        end
      end

      context 'when sort_param is last-fill-date' do
        it 'sorts by dispensed_date descending with secondary sort by prescription_name ascending' do
          result = helper.apply_sorting(resource, 'last-fill-date')

          expect(result.metadata[:sort]).to eq({
                                                 'dispensed_date' => 'DESC',
                                                 'prescription_name' => 'ASC'
                                               })
        end
      end

      context 'when sort_param is unknown' do
        it 'applies default sorting' do
          result = helper.apply_sorting(resource, 'unknown-sort')

          expect(result.metadata[:sort]).to eq({
                                                 'disp_status' => 'ASC',
                                                 'prescription_name' => 'ASC',
                                                 'dispensed_date' => 'DESC'
                                               })
        end
      end
    end

    describe '#build_sort_metadata' do
      it 'returns default metadata for -alphabetical-rx-name (unrecognized sort param)' do
        result = helper.build_sort_metadata('-alphabetical-rx-name')
        # Falls back to default since -alphabetical-rx-name is not a recognized case
        expect(result).to eq({
                               'disp_status' => 'ASC',
                               'prescription_name' => 'ASC',
                               'dispensed_date' => 'DESC'
                             })
      end

      it 'returns last-fill-date metadata for last-fill-date' do
        result = helper.build_sort_metadata('last-fill-date')
        expect(result).to eq({
                               'dispensed_date' => 'DESC',
                               'prescription_name' => 'ASC'
                             })
      end

      it 'returns default metadata for unrecognized sort param' do
        result = helper.build_sort_metadata('-last-fill-date')
        expect(result).to eq({
                               'disp_status' => 'ASC',
                               'prescription_name' => 'ASC',
                               'dispensed_date' => 'DESC'
                             })
      end

      it 'returns alphabetical sort metadata for alphabetical-rx-name' do
        result = helper.build_sort_metadata('alphabetical-rx-name')
        expect(result).to eq({
                               'prescription_name' => 'ASC',
                               'dispensed_date' => 'DESC'
                             })
      end
    end

    describe 'case-insensitive sorting' do
      let(:upper_med) do
        double('upper_med',
               prescription_name: 'BACITRACIN',
               disp_status: 'Active',
               dispensed_date: Date.new(2024, 1, 1),
               prescription_source: 'VA',
               dispenses: [],
               orderable_item: nil)
      end

      let(:lower_med) do
        double('lower_med',
               prescription_name: 'atorvastatin',
               disp_status: 'Active',
               dispensed_date: Date.new(2024, 2, 1),
               prescription_source: 'VA',
               dispenses: [],
               orderable_item: nil)
      end

      let(:title_med) do
        double('title_med',
               prescription_name: 'Celecoxib',
               disp_status: 'Active',
               dispensed_date: Date.new(2024, 3, 1),
               prescription_source: 'VA',
               dispenses: [],
               orderable_item: nil)
      end

      let(:mixed_case_resource) do
        records = [upper_med, lower_med, title_med]
        metadata = {}
        double('resource').tap do |r|
          allow(r).to receive_messages(records:, metadata:)
          allow(r).to receive(:records=) { |new_records| records.replace(new_records) }
          allow(r).to receive(:metadata=) { |new_metadata| metadata.replace(new_metadata) }
        end
      end

      before do
        [upper_med, lower_med, title_med].each do |med|
          allow(med).to receive(:respond_to?).with(:dispenses).and_return(true)
          allow(med).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)
        end
      end

      context 'with alphabetical-rx-name sort' do
        it 'sorts names case-insensitively' do
          result = helper.apply_sorting(mixed_case_resource, 'alphabetical-rx-name')
          names = result.records.map(&:prescription_name)

          expect(names).to eq(%w[atorvastatin BACITRACIN Celecoxib])
        end
      end

      context 'with default sort' do
        it 'sorts names case-insensitively within the same status' do
          result = helper.apply_sorting(mixed_case_resource, nil)
          names = result.records.map(&:prescription_name)

          expect(names).to eq(%w[atorvastatin BACITRACIN Celecoxib])
        end
      end

      context 'with Active: Non-VA medications' do
        let(:non_va_upper) do
          double('non_va_upper',
                 prescription_name: nil,
                 disp_status: 'Active: Non-VA',
                 dispensed_date: Date.new(2024, 1, 1),
                 prescription_source: 'NV',
                 dispenses: [],
                 orderable_item: 'DOCUSATE')
        end

        let(:non_va_lower) do
          double('non_va_lower',
                 prescription_name: nil,
                 disp_status: 'Active: Non-VA',
                 dispensed_date: Date.new(2024, 2, 1),
                 prescription_source: 'NV',
                 dispenses: [],
                 orderable_item: 'aspirin')
        end

        let(:non_va_title) do
          double('non_va_title',
                 prescription_name: nil,
                 disp_status: 'Active: Non-VA',
                 dispensed_date: Date.new(2024, 3, 1),
                 prescription_source: 'NV',
                 dispenses: [],
                 orderable_item: 'Buspirone')
        end

        let(:non_va_resource) do
          records = [non_va_upper, non_va_lower, non_va_title]
          metadata = {}
          double('resource').tap do |r|
            allow(r).to receive_messages(records:, metadata:)
            allow(r).to receive(:records=) { |new_records| records.replace(new_records) }
            allow(r).to receive(:metadata=) { |new_metadata| metadata.replace(new_metadata) }
          end
        end

        before do
          [non_va_upper, non_va_lower, non_va_title].each do |med|
            allow(med).to receive(:respond_to?).with(:dispenses).and_return(true)
            allow(med).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)
          end
        end

        it 'sorts Non-VA orderable_item names case-insensitively with alphabetical-rx-name' do
          result = helper.apply_sorting(non_va_resource, 'alphabetical-rx-name')
          names = result.records.map(&:orderable_item)

          expect(names).to eq(%w[aspirin Buspirone DOCUSATE])
        end
      end
    end

    describe 'sorting with UnifiedHealthData::Prescription objects' do
      # Reproduces production ArgumentError when sorting prescriptions with mixed date types.
      # UnifiedHealthData::Prescription stores sorted_dispensed_date as String and dispensed_date
      # as String, but get_sorted_dispensed_date can return a Date (from extract_last_refill_date)
      # or a String (from sorted_dispensed_date), causing <=> to fail on type mismatch.

      def build_unified_prescription(attrs = {})
        UnifiedHealthData::Prescription.new({
          id: SecureRandom.uuid,
          prescription_name: 'Test Med',
          disp_status: 'Active',
          is_refillable: false,
          is_renewable: false,
          is_trackable: false,
          dispensed_date: nil,
          station_number: '123',
          prescription_source: 'VA',
          dispenses: [],
          sorted_dispensed_date: nil
        }.merge(attrs))
      end

      context 'when one prescription has dispenses (Date) and another uses sorted_dispensed_date (String)' do
        let(:med_with_dispenses) do
          build_unified_prescription(
            prescription_name: 'Aspirin',
            disp_status: 'Active',
            dispenses: [{ refill_date: '2025-03-15' }],
            sorted_dispensed_date: nil
          )
        end

        let(:med_with_string_date) do
          build_unified_prescription(
            prescription_name: 'Aspirin',
            disp_status: 'Active',
            dispenses: [],
            sorted_dispensed_date: '2025-01-10'
          )
        end

        let(:resource) do
          records = [med_with_string_date, med_with_dispenses]
          OpenStruct.new(records:, metadata: {})
        end

        it 'sorts without error when dates are mixed types in default_sort' do
          expect { helper.apply_sorting(resource, nil) }.not_to raise_error
        end

        it 'sorts without error when dates are mixed types in last-fill-date sort' do
          expect { helper.apply_sorting(resource, 'last-fill-date') }.not_to raise_error
        end

        it 'sorts without error when dates are mixed types in alphabetical sort' do
          expect { helper.apply_sorting(resource, 'alphabetical-rx-name') }.not_to raise_error
        end
      end

      context 'when prescriptions only use sorted_dispensed_date strings (no dispenses)' do
        let(:med_a) do
          build_unified_prescription(
            prescription_name: 'Aspirin',
            disp_status: 'Active',
            sorted_dispensed_date: '2025-03-15'
          )
        end

        let(:med_b) do
          build_unified_prescription(
            prescription_name: 'Aspirin',
            disp_status: 'Active',
            sorted_dispensed_date: '2025-01-10'
          )
        end

        let(:resource) do
          OpenStruct.new(records: [med_b, med_a], metadata: {})
        end

        it 'does not raise because both dates are coerced from sorted_dispensed_date (same type)' do
          expect { helper.apply_sorting(resource, nil) }.not_to raise_error
        end
      end

      context 'when sorted_dispensed_date is nil and one prescription has dispenses' do
        let(:med_with_dispenses) do
          build_unified_prescription(
            prescription_name: 'Zoloft',
            disp_status: 'Active',
            dispenses: [{ refill_date: '2025-06-01' }],
            sorted_dispensed_date: nil
          )
        end

        let(:med_with_nil_dates) do
          # sorted_dispensed_date is nil and dispenses is empty. Because
          # UnifiedHealthData::Prescription defines sorted_dispensed_date as an
          # attribute, respond_to?(:sorted_dispensed_date) is true, so
          # get_sorted_dispensed_date returns nil&.to_date (nil) without ever
          # reaching the dispensed_date fallback.
          build_unified_prescription(
            prescription_name: 'Zoloft',
            disp_status: 'Active',
            dispenses: [],
            sorted_dispensed_date: nil,
            dispensed_date: '2025-04-01'
          )
        end

        let(:resource) do
          OpenStruct.new(records: [med_with_nil_dates, med_with_dispenses], metadata: {})
        end

        it 'sorts without error when one date is nil and the other is a Date' do
          expect { helper.apply_sorting(resource, nil) }.not_to raise_error
        end
      end
    end

    describe 'sorting prescriptions built from raw adapter input' do
      include FhirResourceBuilder

      let(:vista_adapter) { UnifiedHealthData::Adapters::VistaPrescriptionAdapter.new }
      # VistA prescription with refill dispenses — adapter sets sorted_dispensed_date from rfRecord dates.
      # The resulting object has dispenses: [{dispensed_date: Date, ...}] and sorted_dispensed_date: "2025-07-20".
      let(:vista_med_with_dispenses) do
        vista_adapter.parse({
                              'prescriptionId' => '111',
                              'prescriptionName' => 'METFORMIN HCL 500MG TAB',
                              'refillStatus' => 'active',
                              'facilityName' => 'Salt Lake City VAMC',
                              'isRefillable' => true,
                              'isTrackable' => false,
                              'prescriptionNumber' => 'RX111',
                              'stationNumber' => '660',
                              'dispStatus' => 'Active',
                              'rxRFRecords' => {
                                'rfRecord' => [
                                  { 'dispensedDate' => 'Thu, 10 Jul 2025 00:00:00 EDT' },
                                  { 'dispensedDate' => 'Sun, 20 Jul 2025 00:00:00 EDT' }
                                ]
                              }
                            })
      end
      # VistA prescription with NO dispenses but a top-level dispensedDate.
      # Adapter sets sorted_dispensed_date from dispensedDate fallback, dispenses is [].
      let(:vista_med_no_dispenses) do
        vista_adapter.parse({
                              'prescriptionId' => '222',
                              'prescriptionName' => 'METFORMIN HCL 500MG TAB',
                              'refillStatus' => 'active',
                              'facilityName' => 'Salt Lake City VAMC',
                              'isRefillable' => true,
                              'isTrackable' => false,
                              'prescriptionNumber' => 'RX222',
                              'stationNumber' => '660',
                              'dispStatus' => 'Active',
                              'dispensedDate' => 'Wed, 01 Jun 2025 00:00:00 EDT'
                            })
      end
      # Oracle Health prescription with a dispense — adapter sets sorted_dispensed_date from whenHandedOver.
      let(:oh_med_with_dispense) do
        oh_adapter.parse(fhir_resource(
          status: 'active',
          source: 'VA',
          dispense_status: 'completed',
          dispense_date: '2025-08-01T10:00:00Z'
        ).merge('id' => '333', 'medicationCodeableConcept' => { 'text' => 'METFORMIN HCL 500MG TAB' }))
      end
      # Oracle Health prescription with NO dispense — sorted_dispensed_date will be nil.
      let(:oh_med_no_dispense) do
        oh_adapter.parse(fhir_resource(
          status: 'active',
          source: 'VA',
          dispense_status: nil
        ).merge(
          'id' => '444',
          'medicationCodeableConcept' => { 'text' => 'METFORMIN HCL 500MG TAB' },
          'contained' => []
        ))
      end
      let(:oh_adapter) { UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter.new }

      before do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_medications_renewal_request,
                                                  nil).and_return(false)
        facility = instance_double(HealthFacility, name: 'Portland VA Medical Center')
        allow(HealthFacility).to receive(:find_by).and_return(facility)
      end

      context 'when mixing VistA (with dispenses) and VistA (no dispenses, string sorted_dispensed_date)' do
        let(:resource) do
          OpenStruct.new(records: [vista_med_no_dispenses, vista_med_with_dispenses], metadata: {})
        end

        it 'sorts via default sort without error' do
          expect { helper.apply_sorting(resource, nil) }.not_to raise_error
        end

        it 'sorts via last-fill-date without error' do
          expect { helper.apply_sorting(resource, 'last-fill-date') }.not_to raise_error
        end

        it 'sorts via alphabetical-rx-name without error' do
          expect { helper.apply_sorting(resource, 'alphabetical-rx-name') }.not_to raise_error
        end
      end

      context 'when mixing Oracle Health (with dispense) and VistA (no dispenses)' do
        let(:resource) do
          OpenStruct.new(records: [oh_med_with_dispense, vista_med_no_dispenses], metadata: {})
        end

        it 'sorts via default sort without error' do
          expect { helper.apply_sorting(resource, nil) }.not_to raise_error
        end

        it 'sorts via last-fill-date without error' do
          expect { helper.apply_sorting(resource, 'last-fill-date') }.not_to raise_error
        end
      end

      context 'when mixing all four variants together' do
        let(:resource) do
          records = [vista_med_with_dispenses, vista_med_no_dispenses,
                     oh_med_with_dispense, oh_med_no_dispense]
          OpenStruct.new(records: records.compact, metadata: {})
        end

        it 'sorts the full mixed collection via default sort without error' do
          expect { helper.apply_sorting(resource, nil) }.not_to raise_error
        end

        it 'sorts the full mixed collection via last-fill-date without error' do
          expect { helper.apply_sorting(resource, 'last-fill-date') }.not_to raise_error
        end

        it 'sorts the full mixed collection via alphabetical-rx-name without error' do
          expect { helper.apply_sorting(resource, 'alphabetical-rx-name') }.not_to raise_error
        end
      end
    end
  end
end
