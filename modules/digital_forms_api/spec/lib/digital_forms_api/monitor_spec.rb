# frozen_string_literal: true

require 'rails_helper'
require 'digital_forms_api/monitor'

RSpec.describe DigitalFormsApi::Monitor do
  let(:base) { DigitalFormsApi::Monitor.new }
  let(:record) { DigitalFormsApi::Monitor::Record.new(build(:claims_evidence_submission)) }
  let(:service) { DigitalFormsApi::Monitor::Service.new }
  let(:uploader) { DigitalFormsApi::Monitor::Uploader.new }

  context 'base monitor functions' do
    describe '#format_message' do
      it 'returns message preceded by class name' do
        msg = base.format_message('TEST')
        expect(msg).to eq "#{subject.class}: TEST"
      end
    end

    describe '#format_tags' do
      it 'returns message preceded by class name' do
        tags = { foo: :bar, 'test' => 23 }
        tags = base.format_tags(tags)
        expect(tags).to eq ['foo:bar', 'test:23']
      end
    end
  end

  context 'Service monitor functions' do
    let(:metric) { DigitalFormsApi::Monitor::Service::METRIC }

    describe '#track_api_request' do
      it 'tracks an OK request' do
        endpoint = 'TEST'
        code = 210
        reason = 'testing ok'
        duration = 42
        call_location = 'foobar'

        tags = { method: :get, code:, endpoint: }
        formatted_tags = ['method:get', 'code:210', 'endpoint:TEST']
        message = "#{service.class}: #{code} #{reason}"

        kwargs = { call_location:, reason:, duration:, tags: formatted_tags, **tags }
        expect(service).to receive(:track_request).with(:info, message, metric, **kwargs)
        expect(StatsD).to receive(:measure).with("#{metric}.duration", duration, tags: anything)

        service.track_api_request(:get, endpoint, code, reason, duration, call_location:)
      end

      it 'tracks an Error request' do
        endpoint = 'TEST'
        code = 404
        reason = 'testing 404'
        duration = 42
        call_location = 'foobar'

        tags = { method: :get, code:, endpoint: }
        formatted_tags = ['method:get', 'code:404', 'endpoint:TEST']
        message = "#{service.class}: #{code} #{reason}"

        kwargs = { call_location:, reason:, duration:, tags: formatted_tags, **tags }
        expect(service).to receive(:track_request).with(:error, message, metric, **kwargs)
        expect(StatsD).to receive(:measure).with("#{metric}.duration", duration, tags: anything)

        service.track_api_request(:get, endpoint, code, reason, duration, call_location:)
      end
    end
  end
end
