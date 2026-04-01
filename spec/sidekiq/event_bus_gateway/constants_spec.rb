# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventBusGateway::Constants do
  include ActiveSupport::Testing::TimeHelpers

  describe '.sms_blackout_period?' do
    let(:eastern) { ActiveSupport::TimeZone['Eastern Time (US & Canada)'] }

    context 'during blackout window' do
      it 'returns true at 9:00 PM Eastern' do
        travel_to eastern.local(2025, 1, 15, 21, 0, 0) do
          expect(described_class.sms_blackout_period?).to be true
        end
      end

      it 'returns true at 11:59 PM Eastern' do
        travel_to eastern.local(2025, 1, 15, 23, 59, 0) do
          expect(described_class.sms_blackout_period?).to be true
        end
      end

      it 'returns true at midnight Eastern' do
        travel_to eastern.local(2025, 1, 16, 0, 0, 0) do
          expect(described_class.sms_blackout_period?).to be true
        end
      end

      it 'returns true at 8:59 AM Eastern' do
        travel_to eastern.local(2025, 1, 16, 8, 59, 0) do
          expect(described_class.sms_blackout_period?).to be true
        end
      end
    end

    context 'outside blackout window' do
      it 'returns false at 9:00 AM Eastern' do
        travel_to eastern.local(2025, 1, 15, 9, 0, 0) do
          expect(described_class.sms_blackout_period?).to be false
        end
      end

      it 'returns false at 12:00 PM Eastern' do
        travel_to eastern.local(2025, 1, 15, 12, 0, 0) do
          expect(described_class.sms_blackout_period?).to be false
        end
      end

      it 'returns false at 8:59 PM Eastern' do
        travel_to eastern.local(2025, 1, 15, 20, 59, 0) do
          expect(described_class.sms_blackout_period?).to be false
        end
      end
    end

    context 'daylight saving time' do
      it 'returns true at 9:00 PM EDT (summer)' do
        travel_to eastern.local(2025, 7, 15, 21, 0, 0) do
          expect(described_class.sms_blackout_period?).to be true
        end
      end

      it 'returns false at 9:00 AM EDT (summer)' do
        travel_to eastern.local(2025, 7, 15, 9, 0, 0) do
          expect(described_class.sms_blackout_period?).to be false
        end
      end

      it 'returns true at 9:00 PM EST (winter)' do
        travel_to eastern.local(2025, 1, 15, 21, 0, 0) do
          expect(described_class.sms_blackout_period?).to be true
        end
      end

      it 'returns false at 9:00 AM EST (winter)' do
        travel_to eastern.local(2025, 1, 15, 9, 0, 0) do
          expect(described_class.sms_blackout_period?).to be false
        end
      end
    end
  end
end
