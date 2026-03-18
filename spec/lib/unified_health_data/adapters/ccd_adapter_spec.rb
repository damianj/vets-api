# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/ccd_adapter'

RSpec.describe UnifiedHealthData::Adapters::CcdAdapter do
  subject(:adapter) { described_class.new }

  describe '#parse' do
    context 'with a flat (pre-ready) response' do
      let(:body) do
        JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_task_not_ready.json').read)
      end

      it 'returns a Ccd model with job metadata' do
        result = adapter.parse(body)

        expect(result).to be_a(UnifiedHealthData::Ccd)
        expect(result.status).to eq('NOT_READY')
        expect(result.job_id).to be_present
        expect(result.task_id).to be_present
        expect(result.source).to be_present
      end

      it 'does not populate format fields' do
        result = adapter.parse(body)

        expect(result.xml).to be_nil
        expect(result.html).to be_nil
        expect(result.pdf).to be_nil
      end
    end

    context 'with a generate response' do
      let(:body) do
        JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_generate.json').read)
      end

      it 'returns a Ccd model with job metadata' do
        result = adapter.parse(body)

        expect(result).to be_a(UnifiedHealthData::Ccd)
        expect(result.job_id).to be_present
        expect(result.task_id).to be_nil
      end
    end

    context 'with a FHIR Bundle (ready) response' do
      let(:body) do
        JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_ready_success.json').read)
      end

      it 'returns a Ccd model with per-format status values' do
        result = adapter.parse(body)

        expect(result).to be_a(UnifiedHealthData::Ccd)
        expect(result.xml).to eq('READY')
        expect(result.html).to eq('READY')
        expect(result.pdf).to eq('READY')
      end

      it 'extracts the task_id from the Binary ccd-task-reference extension' do
        result = adapter.parse(body)

        expect(result.task_id).to eq('12043')
      end

      it 'extracts the authored_on from the DocumentReference' do
        result = adapter.parse(body)

        expect(result.authored_on).to eq('2026-03-03T10:18:36.400-05:00')
      end

      it 'does not populate flat job metadata fields' do
        result = adapter.parse(body)

        expect(result.status).to be_nil
      end

      it 'populates job_id from task_id' do
        result = adapter.parse(body)

        expect(result.job_id).to eq('12043')
      end

      it 'sets source to oracle-health' do
        result = adapter.parse(body)

        expect(result.source).to eq('oracle-health')
      end

      it 'extracts message from the OperationOutcome diagnostics' do
        result = adapter.parse(body)

        expect(result.message).to eq('Success')
      end

      it 'maps content types to correct format keys with status values' do
        result = adapter.parse(body)

        expect(result.xml).to eq('READY')
        expect(result.html).to eq('READY')
        expect(result.pdf).to eq('READY')
      end
    end

    context 'with a Bundle that has no Binary resources' do
      let(:body) do
        {
          'resourceType' => 'Bundle',
          'type' => 'collection',
          'entry' => [
            {
              'resource' => {
                'resourceType' => 'DocumentReference',
                'id' => '999',
                'meta' => { 'lastUpdated' => '2026-01-01T00:00:00Z' }
              }
            }
          ]
        }
      end

      it 'returns nil format fields and nil task_id and derived fields' do
        result = adapter.parse(body)

        expect(result.xml).to be_nil
        expect(result.html).to be_nil
        expect(result.pdf).to be_nil
        expect(result.task_id).to be_nil
        expect(result.job_id).to be_nil
        expect(result.source).to eq('oracle-health')
        expect(result.message).to be_nil
      end
    end

    context 'with a Bundle where Binary has no ccd-task-reference extension' do
      let(:body) do
        {
          'resourceType' => 'Bundle',
          'type' => 'collection',
          'entry' => [
            {
              'resource' => {
                'resourceType' => 'Binary',
                'id' => '100',
                'contentType' => 'application/xml',
                'meta' => {
                  'extension' => [
                    {
                      'url' => 'http://va.gov/mhv/fhir/StructureDefinition/presigned-url',
                      'valueUrl' => 'https://example.com/file.xml'
                    }
                  ]
                }
              }
            }
          ]
        }
      end

      it 'returns nil task_id and nil format status when no format-status extension exists' do
        result = adapter.parse(body)

        expect(result.task_id).to be_nil
        expect(result.xml).to be_nil
      end
    end

    context 'with a nil body' do
      it 'returns a Ccd model with nil fields' do
        result = adapter.parse(nil)

        expect(result).to be_a(UnifiedHealthData::Ccd)
      end
    end

    context 'with an empty hash body' do
      it 'returns a Ccd model with nil fields from flat parse' do
        result = adapter.parse({})

        expect(result).to be_a(UnifiedHealthData::Ccd)
        expect(result.status).to be_nil
        expect(result.job_id).to be_nil
      end
    end
  end

  describe '#parse_tasks' do
    context 'with a mixed jobs response (some artifacts exist, some do not)' do
      let(:body) do
        JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_patient_all_jobs_mixed.json').read)
      end

      it 'returns an array of Ccd models for each Task entry' do
        result = adapter.parse_tasks(body)

        expect(result).to be_an(Array)
        expect(result.size).to eq(3)
        expect(result).to all(be_a(UnifiedHealthData::Ccd))
      end

      it 'extracts task_id from each Task resource' do
        result = adapter.parse_tasks(body)

        expect(result.map(&:task_id)).to eq(%w[5001 5002 5003])
      end

      it 'extracts status from each Task' do
        result = adapter.parse_tasks(body)

        expect(result.map(&:status)).to all(eq('completed'))
      end

      it 'extracts business status as message' do
        result = adapter.parse_tasks(body)

        expect(result.map(&:message)).to all(eq('FULL_SUCCESS'))
      end

      it 'populates format fields with businessStatus when no failureCode is present' do
        result = adapter.parse_tasks(body)

        # All tasks in the mixed fixture succeeded, so each format gets the businessStatus
        result.each do |ccd|
          expect(ccd.xml).to eq('FULL_SUCCESS')
          expect(ccd.html).to eq('FULL_SUCCESS')
          expect(ccd.pdf).to eq('FULL_SUCCESS')
        end
      end

      it 'uses authoredOn as authored_on' do
        result = adapter.parse_tasks(body)

        # Tasks in the mixed fixture have no authoredOn, so authored_on is nil
        expect(result.map(&:authored_on)).to all(be_nil)
      end

      it 'ignores OperationOutcome entries' do
        result = adapter.parse_tasks(body)

        expect(result.none? { |ccd| ccd.task_id.nil? }).to be true
      end
    end

    context 'with an error jobs response (all artifacts failed)' do
      let(:body) do
        JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_patient_all_jobs_errors.json').read)
      end

      it 'returns an array with one Ccd model' do
        result = adapter.parse_tasks(body)

        expect(result.size).to eq(1)
      end

      it 'extracts the failed task metadata' do
        result = adapter.parse_tasks(body).first

        expect(result.task_id).to eq('4052')
        expect(result.status).to eq('failed')
        expect(result.message).to eq('NON_RETRYABLE_FAILURE')
      end

      it 'populates format fields with per-format failureCode' do
        result = adapter.parse_tasks(body).first

        expect(result.xml).to eq('CCD_XML_UPLOAD_FAILED')
        expect(result.html).to eq('CCD_CONVERSION_HTML_FAILED')
        expect(result.pdf).to eq('CCD_CONVERSION_PDF_FAILED')
      end

      it 'extracts source from meta tags' do
        result = adapter.parse_tasks(body).first

        expect(result.source).to eq('oracle-health')
      end

      it 'uses authoredOn as authored_on' do
        result = adapter.parse_tasks(body).first

        expect(result.authored_on).to eq('2026-03-10T13:51:01+00:00')
      end
    end

    context 'with an empty Bundle' do
      let(:body) { { 'resourceType' => 'Bundle', 'type' => 'searchset', 'entry' => [] } }

      it 'returns an empty array' do
        result = adapter.parse_tasks(body)

        expect(result).to eq([])
      end
    end

    context 'with a nil body' do
      it 'returns an empty array' do
        result = adapter.parse_tasks(nil)

        expect(result).to eq([])
      end
    end

    context 'with a Bundle containing only OperationOutcome entries' do
      let(:body) do
        {
          'resourceType' => 'Bundle',
          'type' => 'searchset',
          'entry' => [
            {
              'resource' => {
                'resourceType' => 'OperationOutcome',
                'issue' => [{ 'severity' => 'information', 'diagnostics' => 'No tasks found' }]
              }
            }
          ]
        }
      end

      it 'returns an empty array' do
        result = adapter.parse_tasks(body)

        expect(result).to eq([])
      end
    end
  end

  describe '#parse_url' do
    context 'with a FHIR Bundle (ready) response' do
      let(:body) do
        JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_ready_success.json').read)
      end

      it 'returns the presigned URL for xml format' do
        result = adapter.parse_url(body, format: 'xml')

        expect(result).to be_present
        expect(result).to include('original.xml')
      end

      it 'returns the presigned URL for html format' do
        result = adapter.parse_url(body, format: 'html')

        expect(result).to be_present
        expect(result).to include('rendered.html')
      end

      it 'returns the presigned URL for pdf format' do
        result = adapter.parse_url(body, format: 'pdf')

        expect(result).to be_present
        expect(result).to include('rendered.pdf')
      end

      it 'accepts format as a symbol' do
        result = adapter.parse_url(body, format: :pdf)

        expect(result).to be_present
        expect(result).to include('rendered.pdf')
      end

      it 'returns nil for an unknown format' do
        result = adapter.parse_url(body, format: 'txt')

        expect(result).to be_nil
      end
    end

    context 'with a Bundle that has no Binary resources' do
      let(:body) do
        {
          'resourceType' => 'Bundle',
          'type' => 'collection',
          'entry' => [
            {
              'resource' => {
                'resourceType' => 'DocumentReference',
                'id' => '999',
                'meta' => { 'lastUpdated' => '2026-01-01T00:00:00Z' }
              }
            }
          ]
        }
      end

      it 'returns nil for any format' do
        expect(adapter.parse_url(body, format: 'xml')).to be_nil
        expect(adapter.parse_url(body, format: 'html')).to be_nil
        expect(adapter.parse_url(body, format: 'pdf')).to be_nil
      end
    end

    context 'with a nil body' do
      it 'returns nil' do
        result = adapter.parse_url(nil, format: 'xml')

        expect(result).to be_nil
      end
    end
  end
end
