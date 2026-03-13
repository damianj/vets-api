# frozen_string_literal: true

require 'rails_helper'
require 'digital_forms_api/service/forms'

RSpec.describe DigitalFormsApi::Service::Forms do
  let(:service) { described_class.new }
  let(:form_id) { '21-686c' }
  let(:schema_cache_key) { described_class.schema_cache_key(form_id) }
  let(:template_cache_key) { described_class.template_cache_key(form_id) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '#schema' do
    let(:schema_body) { { 'schema' => 'data' } }
    let(:faraday_env) { instance_double(Faraday::Env, body: schema_body, status: 200) }

    context 'when schema is not cached' do
      it 'performs a GET request to the forms endpoint' do
        expect(service).to receive(:perform).with(:get, "forms/#{form_id}/schema", {}, {}).and_return(faraday_env)
        service.schema(form_id)
      end

      it 'caches only the response body' do
        allow(service).to receive(:perform).and_return(faraday_env)

        service.schema(form_id)

        cached = Rails.cache.read(schema_cache_key)
        expect(cached).to eq(schema_body)
      end

      it 'returns the parsed body from the API' do
        allow(service).to receive(:perform).and_return(faraday_env)

        result = service.schema(form_id)

        expect(result).to eq(schema_body)
      end
    end

    context 'when schema is called twice' do
      it 'only calls the upstream service once' do
        expect(service).to receive(:perform)
          .with(:get, "forms/#{form_id}/schema", {}, {})
          .once
          .and_return(faraday_env)

        first_result  = service.schema(form_id)
        second_result = service.schema(form_id)

        expect(first_result).to eq(schema_body)
        expect(second_result).to eq(schema_body)
      end
    end

    context 'when schema is cached' do
      it 'returns the cached body without making an API request' do
        Rails.cache.write(schema_cache_key, schema_body)

        expect(service).not_to receive(:perform)

        result = service.schema(form_id)

        expect(result).to eq(schema_body)
      end
    end
  end

  describe '#template' do
    let(:template_body) { { 'template' => 'data' } }
    let(:faraday_env) { instance_double(Faraday::Env, body: template_body, status: 200) }

    context 'when template is not cached' do
      it 'performs a GET request to the forms endpoint' do
        expect(service).to receive(:perform).with(:get, "forms/#{form_id}/template", {}, {}).and_return(faraday_env)
        service.template(form_id)
      end

      it 'caches only the response body' do
        allow(service).to receive(:perform).and_return(faraday_env)

        service.template(form_id)

        cached = Rails.cache.read(template_cache_key)
        expect(cached).to eq(template_body)
      end

      it 'returns the parsed body from the API' do
        allow(service).to receive(:perform).and_return(faraday_env)

        result = service.template(form_id)

        expect(result).to eq(template_body)
      end
    end

    context 'when template is called twice' do
      it 'only calls the upstream service once' do
        expect(service).to receive(:perform)
          .with(:get, "forms/#{form_id}/template", {}, {})
          .once
          .and_return(faraday_env)

        first_result  = service.template(form_id)
        second_result = service.template(form_id)

        expect(first_result).to eq(template_body)
        expect(second_result).to eq(template_body)
      end
    end

    context 'when template is cached' do
      it 'returns the cached body without making an API request' do
        Rails.cache.write(template_cache_key, template_body)

        expect(service).not_to receive(:perform)

        result = service.template(form_id)

        expect(result).to eq(template_body)
      end
    end
  end
end
