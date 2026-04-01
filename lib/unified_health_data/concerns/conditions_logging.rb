# frozen_string_literal: true

require 'medical_records/medical_records_log'

module UnifiedHealthData
  module Concerns
    # Logging and metrics for conditions. Follows ClinicalNotesLogging pattern.
    # See MedicalRecords::MedicalRecordsLog "Adding a New Domain" guide.
    #
    # Stub Flipper in tests (never use Flipper.enable/disable):
    #   allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_conditions_diagnostic, user).and_return(true)
    module ConditionsLogging
      extend ActiveSupport::Concern

      CONDITIONS = MedicalRecords::MedicalRecordsLog::CONDITIONS
      HIGH_FILTER_RATE_THRESHOLD = 0.5

      private

      def mr_log
        @mr_log ||= MedicalRecords::MedicalRecordsLog.new(user: @user)
      end

      def conditions_logging_enabled?
        mr_log.diagnostic_enabled?(CONDITIONS)
      end

      def conditions_statsd_prefix
        "#{self.class::STATSD_KEY_PREFIX}.conditions"
      end

      def log_conditions_response_count(raw_count, returned_count)
        mr_log.diagnostic(
          resource: CONDITIONS, action: 'filter',
          total_entries: raw_count, returned: returned_count, filtered: raw_count - returned_count
        )
      end

      def log_conditions_index_metrics(combined_records, returned_count)
        vista_count = combined_records.count { |r| r['source'] == SourceConstants::VISTA }
        oh_count = combined_records.count { |r| r['source'] == SourceConstants::ORACLE_HEALTH }

        mr_log.diagnostic(
          resource: CONDITIONS, action: 'index',
          total_conditions: returned_count, vista_raw: vista_count, oracle_health_raw: oh_count
        )

        StatsD.gauge("#{conditions_statsd_prefix}.index.total", returned_count)
        StatsD.gauge("#{conditions_statsd_prefix}.index.vista", vista_count)
        StatsD.gauge("#{conditions_statsd_prefix}.index.oracle_health", oh_count)
      end

      # Always-on: warns when more than half of condition records are dropped during parsing.
      def warn_conditions_high_filter_rate(raw_count, returned_count, source_breakdown: {})
        return if raw_count.zero?

        filter_rate = 1.0 - (returned_count.to_f / raw_count)
        return unless filter_rate > HIGH_FILTER_RATE_THRESHOLD

        mr_log.warn(
          resource: CONDITIONS, action: 'index',
          anomaly: 'high_filter_rate',
          filter_rate: (filter_rate * 100).round(1),
          raw_count:, returned_count:,
          **source_breakdown
        )

        StatsD.increment("#{conditions_statsd_prefix}.anomaly.high_filter_rate")
      end

      # Diagnostic: logs raw entry counts per source from SCDF before any filtering.
      # Helps distinguish "SCDF returned nothing" from "our filters dropped everything".
      def log_conditions_raw_source_counts(body)
        return unless conditions_logging_enabled?

        vista_count = body.dig(SourceConstants::VISTA, 'entry')&.size || 0
        oh_count = body.dig(SourceConstants::ORACLE_HEALTH, 'entry')&.size || 0

        mr_log.diagnostic(
          resource: CONDITIONS, action: 'index',
          stage: 'raw_from_scdf',
          vista_entry_count: vista_count,
          oracle_health_entry_count: oh_count,
          total_entry_count: vista_count + oh_count
        )
      end

      # Structured error log for get_conditions failures — provides domain context for triage.
      def log_conditions_error(error)
        mr_log.error(
          resource: CONDITIONS, action: 'index',
          error_class: error.class.name, error_message: error.message
        )
        StatsD.increment("#{conditions_statsd_prefix}.error")
      end

      # Orchestrates index-level metrics and proactive warnings for get_conditions.
      def log_conditions_metrics(combined_records, parsed_conditions)
        raw_count = combined_records.size
        returned_count = parsed_conditions.size

        vista_raw = combined_records.count { |r| r['source'] == SourceConstants::VISTA }
        oh_raw = combined_records.count { |r| r['source'] == SourceConstants::ORACLE_HEALTH }
        source_breakdown = { vista_raw:, oracle_health_raw: oh_raw }

        conditions_logging_enabled? && log_conditions_response_count(raw_count, returned_count)
        conditions_logging_enabled? && log_conditions_index_metrics(combined_records, returned_count)
        warn_conditions_high_filter_rate(raw_count, returned_count, source_breakdown:)
      end
    end
  end
end
