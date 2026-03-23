# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form210779',
               type: :request do
  include StatsD::Instrument::Helpers
  let(:form_data) { { form: VetsJsonSchema::EXAMPLES['21-0779'].to_json }.to_json }
  let(:saved_claim) { create(:va210779) }
  let(:user) { create(:user, :loa1) }

  describe 'when unauthenticated' do
    context 'when aquia_bio_auth_required is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:form_0779_enabled, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:aquia_bio_auth_required, anything).and_return(true)
      end

      describe 'POST /v0/form210779' do
        it 'returns 401 Unauthorized' do
          post('/v0/form210779', params: form_data, headers: { 'Content-Type' => 'application/json' })
          expect(response).to have_http_status(:unauthorized)
        end
      end

      describe 'GET /v0/form210779/download_pdf' do
        it 'returns 401 Unauthorized' do
          get("/v0/form210779/download_pdf/#{saved_claim.guid}", headers: { 'Content-Type' => 'application/json' })
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when aquia_bio_auth_required is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:form_0779_enabled, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:aquia_bio_auth_required, anything).and_return(false)
      end

      describe 'POST /v0/form210779' do
        it 'allows unauthenticated access' do
          post('/v0/form210779', params: form_data, headers: { 'Content-Type' => 'application/json' })
          expect(response).to have_http_status(:ok)
        end
      end

      describe 'GET /v0/form210779/download_pdf' do
        it 'allows unauthenticated access' do
          get("/v0/form210779/download_pdf/#{saved_claim.guid}", headers: { 'Content-Type' => 'application/json' })
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'POST /v0/form210779' do
    before do
      sign_in_as(user)
    end

    context 'when inflection header provided' do
      it 'returns a success' do
        metrics = capture_statsd_calls do
          post(
            '/v0/form210779',
            params: form_data,
            headers: {
              'Content-Type' => 'application/json',
              'X-Key-Inflection' => 'camel',
              'HTTP_SOURCE_APP_NAME' => '21-0779-nursing-home-information'
            }
          )
        end
        expect(response).to have_http_status(:ok)
        expect(metrics.collect(&:source)).to include(
          'saved_claim.create:1|c|#form_id:21-0779,doctype:222',
          'shared.sidekiq.default.Lighthouse_SubmitBenefitsIntakeClaim.enqueue:1|c',
          'api.form210779.submission.begun:1|c|#service:form210779,function:track_submission_begun,' \
          'action:create,status:begun,form_id:21-0779',
          'api.form210779.submission.success:1|c|#service:form210779,function:track_submission_success,' \
          'action:create,status:success,form_id:21-0779',
          'api.form210779.request:1|c|#service:form210779,function:track_request_code,' \
          'status_code:200,action:create,form_id:21-0779',
          'api.rack.request:1|c|#controller:v0/form210779,action:create,source_app:21-0779-nursing-home-information,' \
          'status:200'
        )
      end
    end
  end

  describe 'GET /v0/form210779/download_pdf' do
    before do
      sign_in_as(user)
    end

    it 'returns a success' do
      metrics = capture_statsd_calls do
        get("/v0/form210779/download_pdf/#{saved_claim.guid}", headers: {
              'Content-Type' => 'application/json',
              'HTTP_SOURCE_APP_NAME' => '21-0779-nursing-home-information'
            })
      end
      expect(metrics.collect(&:source)).to include(
        'api.form210779.pdf_generation.success:1|c|#service:form210779,function:track_pdf_generation_success,' \
        'action:download_pdf,status:success,form_id:21-0779',
        'api.form210779.request:1|c|#service:form210779,function:track_request_code,' \
        'status_code:200,action:download_pdf,form_id:21-0779',
        'api.rack.request:1|c|#controller:v0/form210779,action:download_pdf,' \
        'source_app:21-0779-nursing-home-information,status:200'
      )
      # Check for duration metric (type 'ms' for measure)
      duration_metrics = metrics.select { |m| m.name == 'api.form210779.pdf_generation.duration' }
      expect(duration_metrics).not_to be_empty

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
    end

    it 'returns 500 when to_pdf returns error' do
      allow_any_instance_of(SavedClaim::Form210779).to receive(:to_pdf).and_raise(StandardError, 'PDF generation error')

      metrics = capture_statsd_calls do
        get("/v0/form210779/download_pdf/#{saved_claim.guid}", headers: {
              'Content-Type' => 'application/json',
              'HTTP_SOURCE_APP_NAME' => '21-0779-nursing-home-information'
            })
      end
      expect(metrics.collect(&:source)).to include(
        'api.form210779.pdf_generation.failure:1|c|#service:form210779,function:track_pdf_generation_failure,' \
        'action:download_pdf,status:failure,form_id:21-0779',
        'api.form210779.request:1|c|#service:form210779,function:track_request_code,' \
        'status_code:500,action:download_pdf,form_id:21-0779',
        'api.rack.request:1|c|#controller:v0/form210779,action:download_pdf,' \
        'source_app:21-0779-nursing-home-information,status:500'
      )

      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)['errors']).to be_present
      expect(JSON.parse(response.body)['errors'].first['status']).to eq('500')
    end
  end
end
