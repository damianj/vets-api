# frozen_string_literal: true

require 'sidekiq'
require_relative 'constants'

module EventBusGateway
  class LetterReadyRetrySmsJob
    include Sidekiq::Job

    class EventBusGatewayNotificationNotFoundError < StandardError; end

    STATSD_METRIC_PREFIX = 'event_bus_gateway.letter_ready_retry_sms'

    sidekiq_options retry: Constants::SIDEKIQ_RETRY_COUNT_RETRY_SMS

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      timestamp = Time.now.utc

      ::Rails.logger.error('LetterReadyRetrySmsJob retries exhausted',
                           { job_id:, timestamp:, error_class:, error_message: })
      StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted", tags: Constants::DD_TAGS)
    end

    def perform(participant_id, template_id, personalisation, notification_id)
      if Flipper.enabled?(:event_bus_gateway_sms_blackout) && Constants.sms_blackout_period?
        log_sms_blackout_blocked(template_id)
        return
      end

      if Flipper.enabled?(:event_bus_gateway_sms_dry_run)
        log_sms_dry_run(template_id, notification_id)
        return
      end

      original_notification = EventBusGatewayNotification.find_by(id: notification_id)
      raise EventBusGatewayNotificationNotFoundError if original_notification.nil?

      response = notify_client.send_sms(
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation:
      )

      increment_attempts_counter(original_notification, response.id)
      StatsD.increment("#{STATSD_METRIC_PREFIX}.success", tags: Constants::DD_TAGS)
    rescue => e
      record_sms_send_failure(e)
      raise
    end

    private

    def log_sms_dry_run(template_id, notification_id)
      ::Rails.logger.info(
        'LetterReadyRetrySmsJob dry run - SMS not sent',
        { notification_type: 'sms', template_id:, notification_id: }
      )
      StatsD.increment("#{STATSD_METRIC_PREFIX}.dry_run", tags: Constants::DD_TAGS)
    end

    def log_sms_blackout_blocked(template_id)
      ::Rails.logger.info(
        'LetterReadyRetrySmsJob blocked during SMS blackout period',
        {
          notification_type: 'sms',
          reason: 'blackout_period',
          template_id:,
          current_time_utc: Time.current.utc.iso8601
        }
      )
      tags = Constants::DD_TAGS + ['notification_type:sms', 'reason:blackout_period']
      StatsD.increment("#{STATSD_METRIC_PREFIX}.blocked", tags:)
    end

    def notify_client
      @notify_client ||= VaNotify::Service.new(Constants::NOTIFY_SETTINGS.api_key,
                                               { callback_klass: 'EventBusGateway::VANotifySmsStatusCallback' })
    end

    def increment_attempts_counter(original_notification, new_va_notify_id)
      original_notification.update!(
        attempts: original_notification.attempts + 1,
        va_notify_id: new_va_notify_id
      )
    end

    def record_sms_send_failure(error)
      error_message = 'LetterReadyRetrySmsJob sms error'
      ::Rails.logger.error(error_message, { message: error.message })
      tags = Constants::DD_TAGS + ["function: #{error_message}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.failure", tags:)
    end
  end
end
