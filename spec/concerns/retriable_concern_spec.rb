# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RetriableConcern do
  let(:dummy_class) { Class.new { include RetriableConcern }.new }
  let(:block_name) { 'Doing a thing' }

  describe '#with_retries' do
    context 'when the block succeeds on the first attempt' do
      it 'returns the result immediately' do
        result = dummy_class.with_retries(block_name) { 'success' }
        expect(result).to eq('success')
      end
    end

    context 'when the block fails and then succeeds' do
      it 'retries the operation and returns the successful result' do
        expect(Rails.logger).to receive(:warn)
          .with("Retrying #{block_name} (Attempt 1/3): Timeout::Error")

        attempts = 0

        result = dummy_class.with_retries(block_name, tries: 3) do
          attempts += 1
          raise Timeout::Error, 'Temporary failure' if attempts < 2

          'success'
        end

        expect(result).to eq('success')
        expect(attempts).to eq(2)
      end
    end

    context 'when the block fails all attempts' do
      it 'raises an error after max retries' do
        expect(Rails.logger).to receive(:warn)
          .with("Retrying #{block_name} (Attempt 1/3): Timeout::Error")
        expect(Rails.logger).to receive(:warn)
          .with("Retrying #{block_name} (Attempt 2/3): Timeout::Error")
        expect(Rails.logger).to receive(:error).with(
          "#{block_name} failed after max retries",
          hash_including(error: 'Permanent failure', backtrace: kind_of(Array))
        )

        attempts = 0

        expect do
          dummy_class.with_retries(block_name, tries: 3) do
            attempts += 1
            raise Timeout::Error, 'Permanent failure'
          end
        end.to raise_error(Timeout::Error, 'Permanent failure')

        expect(attempts).to eq(3)
      end
    end

    context 'when the block raises a non-retryable error' do
      it 'raises immediately without retrying' do
        attempts = 0

        expect do
          dummy_class.with_retries(block_name, tries: 3) do
            attempts += 1
            raise StandardError, 'not retryable'
          end
        end.to raise_error(StandardError, 'not retryable')

        expect(attempts).to eq(1)
      end
    end
  end
end
