# frozen_string_literal: true

require 'digital_forms_api/monitor'

shared_examples_for 'a DigitalFormsApi::Service class' do
  let(:monitor) { DigitalFormsApi::Monitor::Service.new }

  before do
    allow(DigitalFormsApi::Monitor::Service).to receive(:new).and_return monitor
  end

  describe '#perform' do
    let(:service) { subject.class.new } # instance of the invoking class
    let(:endpoint) { service.send(:endpoint) || 'test' }

    it 'tracks the request' do
      # 'Authorization' is added to each request
      args = [:get, 'test/path', { param: 1 }, { header: 'test', 'Authorization' => /Bearer/ }, { option: 'test' }]
      response = build(:digital_forms_service_response, :success)

      # 'request' is a method within the `super` chain
      expect(service).to receive(:request).with(*args).and_return response
      # method, endpoint, code, reason, duration
      expect(monitor).to receive(:track_api_request).with(:get, endpoint, 200, 'OK', anything, call_location: anything)

      service.perform(*args)
    end

    context 'tracks and raise exception on error response' do
      it 'uses the error message' do
        # 'Authorization' is added to each request
        args = [:get, 'test/path', { param: 1 }, { header: 'test', 'Authorization' => /Bearer/ }, { option: 'test' }]
        error = build(:digital_forms_service_error, :error)
        message = 'Service unavailable.'

        # 'request' is a method within the `super` chain
        expect(service).to receive(:request).with(*args).and_raise error
        # method, endpoint, code, reason, duration
        expect(monitor).to receive(:track_api_request).with(:get, endpoint, 503, message, anything,
                                                            call_location: anything, error: message)

        expect { service.perform(*args) }.to raise_error error
      end

      it 'uses the only message' do
        # 'Authorization' is added to each request
        args = [:get, 'test/path', { param: 1 }, { header: 'test', 'Authorization' => /Bearer/ }, { option: 'test' }]
        error = build(:digital_forms_service_error, :single)
        message = 'I am a teapot.'

        # 'request' is a method within the `super` chain
        expect(service).to receive(:request).with(*args).and_raise error
        # method, endpoint, code, reason, duration
        expect(monitor).to receive(:track_api_request).with(:get, endpoint, 418, message, anything,
                                                            call_location: anything, error: [message])

        expect { service.perform(*args) }.to raise_error error
      end

      it 'uses the first message' do
        # 'Authorization' is added to each request
        args = [:get, 'test/path', { param: 1 }, { header: 'test', 'Authorization' => /Bearer/ }, { option: 'test' }]
        error = build(:digital_forms_service_error, :multiple)
        messages = [
          'Access denied.',
          'I am a teapot.'
        ]

        # 'request' is a method within the `super` chain
        expect(service).to receive(:request).with(*args).and_raise error
        # method, endpoint, code, reason, duration
        expect(monitor).to receive(:track_api_request).with(:get, endpoint, 403, messages.first, anything,
                                                            call_location: anything, error: messages)

        expect { service.perform(*args) }.to raise_error error
      end
    end
  end
end
