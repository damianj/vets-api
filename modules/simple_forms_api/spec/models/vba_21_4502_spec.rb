# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA214502 do
  describe '#notification_first_name' do
    let(:data) do
      {
        'full_name' => {
          'first' => 'Taylor',
          'middle' => 'A',
          'last' => 'Veteran'
        }
      }
    end

    it 'returns the first name to be used in notifications' do
      expect(described_class.new(data).notification_first_name).to eq 'Taylor'
    end
  end

  describe '#notification_email_address' do
    let(:data) do
      { 'email' => 'a@b.com' }
    end

    it 'returns the email address to be used in notifications' do
      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end

  describe '#driver?' do
    it 'returns bool if veteran is driver' do
      data = {
        'veteran_will_operate_vehicle' => true
      }
      model = SimpleFormsApi::VBA214502.new(data)
      expect(model.driver?).to be(true)
      model.data['veteran_will_operate_vehicle'] = false
      expect(model.driver?).to be(false)

      model.data['veteran_will_operate_vehicle'] = 'true'
      expect(model.driver?).to be(true)

      model.data['veteran_will_operate_vehicle'] = 'false'
      expect(model.driver?).to be(false)

      model.data['veteran_will_operate_vehicle'] = ''
      expect(model.driver?).to be(false)

      model.data['veteran_will_operate_vehicle'] = nil
      expect(model.driver?).to be(false)
    end
  end

  describe '#track_user_identity' do
    let(:data) do
      {
        'veteran_will_operate_vehicle' => true
      }
    end

    it 'Logs if veteran is driver' do
      allow(SemanticLogger::Logger).to receive(:new).and_return(Rails.logger)
      allow(Rails.logger).to receive(:info)
      identity = 'driver'
      confirmation_number = '123abc'
      model = SimpleFormsApi::VBA214502.new({ 'veteran_will_operate_vehicle' => true })
      model.track_user_identity('123abc')
      expect(Rails.logger).to have_received(:info).with(
        'Simple forms api - 21-4502 submission user identity',
        identity:,
        confirmation_number:
      )
    end

    it 'Logs if veteran is passenger' do
      allow(SemanticLogger::Logger).to receive(:new).and_return(Rails.logger)
      allow(Rails.logger).to receive(:info)
      identity = 'passenger'
      confirmation_number = '123abc'
      model = SimpleFormsApi::VBA214502.new({ 'veteran_will_operate_vehicle' => false })
      model.track_user_identity('123abc')
      expect(Rails.logger).to have_received(:info).with(
        'Simple forms api - 21-4502 submission user identity',
        identity:,
        confirmation_number:
      )
    end
  end
end
