# frozen_string_literal: true

require 'medical_records/medical_records_log'

module UnifiedHealthData
  module Concerns
    # Logging and metrics for vitals. Follows ClinicalNotesLogging pattern.
    # See MedicalRecords::MedicalRecordsLog "Adding a New Domain" guide.
    #
    # Stub Flipper in tests (never use Flipper.enable/disable):
    #   allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_vitals_diagnostic, user).and_return(true)
    module VitalsLogging
      extend ActiveSupport::Concern

      VITALS = MedicalRecords::MedicalRecordsLog::VITALS
      HIGH_FILTER_RATE_THRESHOLD = 0.5

      private

      def mr_log
        @mr_log ||= MedicalRecords::MedicalRecordsLog.new(user: @user)
      end

      def vitals_logging_enabled?
        mr_log.diagnostic_enabled?(VITALS)
      end

      def vitals_statsd_prefix
        "#{self.class::STATSD_KEY_PREFIX}.vitals"
      end

      def log_vitals_response_count(raw_count, returned_count)
        mr_log.diagnostic(
          resource: VITALS, action: 'filter',
          total_entries: raw_count, returned: returned_count, filtered: raw_count - returned_count
        )
      end

      def log_vitals_index_metrics(combined_records, returned_count)
        vista_count = combined_records.count { |r| r['source'] == SourceConstants::VISTA }
        oh_count = combined_records.count { |r| r['source'] == SourceConstants::ORACLE_HEALTH }

        mr_log.diagnostic(
          resource: VITALS, action: 'index',
          total_vitals: returned_count, vista_raw: vista_count, oracle_health_raw: oh_count
        )

        StatsD.gauge("#{vitals_statsd_prefix}.index.total", returned_count)
        StatsD.gauge("#{vitals_statsd_prefix}.index.vista", vista_count)
        StatsD.gauge("#{vitals_statsd_prefix}.index.oracle_health", oh_count)
      end

      # Always-on: warns when more than half of vital records are dropped during parsing.
      def warn_vitals_high_filter_rate(raw_count, returned_count, source_breakdown: {})
        return if raw_count.zero?

        filter_rate = 1.0 - (returned_count.to_f / raw_count)
        return unless filter_rate > HIGH_FILTER_RATE_THRESHOLD

        mr_log.warn(
          resource: VITALS, action: 'index',
          anomaly: 'high_filter_rate',
          filter_rate: (filter_rate * 100).round(1),
          raw_count:, returned_count:,
          **source_breakdown
        )

        StatsD.increment("#{vitals_statsd_prefix}.anomaly.high_filter_rate")
      end

      # Diagnostic: logs raw entry counts per source from SCDF before any filtering.
      # Helps distinguish "SCDF returned nothing" from "our filters dropped everything".
      def log_vitals_raw_source_counts(body)
        return unless vitals_logging_enabled?

        vista_count = body.dig(SourceConstants::VISTA, 'entry')&.size || 0
        oh_count = body.dig(SourceConstants::ORACLE_HEALTH, 'entry')&.size || 0

        mr_log.diagnostic(
          resource: VITALS, action: 'index',
          stage: 'raw_from_scdf',
          vista_entry_count: vista_count,
          oracle_health_entry_count: oh_count,
          total_entry_count: vista_count + oh_count
        )
      end

      # Structured error log for get_vitals failures — provides domain context for triage.
      def log_vitals_error(error)
        mr_log.error(
          resource: VITALS, action: 'index',
          error_class: error.class.name, error_message: error.message
        )
        StatsD.increment("#{vitals_statsd_prefix}.error")
      end

      # Orchestrates index-level metrics and proactive warnings for get_vitals.
      def log_vitals_metrics(combined_records, parsed_vitals)
        raw_count = combined_records.size
        returned_count = parsed_vitals.size

        vista_raw = combined_records.count { |r| r['source'] == SourceConstants::VISTA }
        oh_raw = combined_records.count { |r| r['source'] == SourceConstants::ORACLE_HEALTH }
        source_breakdown = { vista_raw:, oracle_health_raw: oh_raw }

        vitals_logging_enabled? && log_vitals_response_count(raw_count, returned_count)
        vitals_logging_enabled? && log_vitals_index_metrics(combined_records, returned_count)
        warn_vitals_high_filter_rate(raw_count, returned_count, source_breakdown:)
      end
    end
  end
end
