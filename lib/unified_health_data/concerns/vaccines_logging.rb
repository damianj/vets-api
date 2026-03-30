# frozen_string_literal: true

require 'medical_records/medical_records_log'

module UnifiedHealthData
  module Concerns
    # Logging and metrics for vaccines/immunizations. Follows ClinicalNotesLogging pattern.
    # See MedicalRecords::MedicalRecordsLog "Adding a New Domain" guide.
    #
    # Stub Flipper in tests (never use Flipper.enable/disable):
    #   allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_vaccines_diagnostic, user).and_return(true)
    module VaccinesLogging
      extend ActiveSupport::Concern

      VACCINES = MedicalRecords::MedicalRecordsLog::VACCINES
      HIGH_FILTER_RATE_THRESHOLD = 0.5

      private

      def mr_log
        @mr_log ||= MedicalRecords::MedicalRecordsLog.new(user: @user)
      end

      def vaccines_logging_enabled?
        mr_log.diagnostic_enabled?(VACCINES)
      end

      def vaccines_statsd_prefix
        "#{self.class::STATSD_KEY_PREFIX}.vaccines"
      end

      def log_vaccines_response_count(raw_count, returned_count)
        mr_log.diagnostic(
          resource: VACCINES, action: 'filter',
          total_entries: raw_count, returned: returned_count, filtered: raw_count - returned_count
        )
      end

      def log_vaccines_index_metrics(combined_records, returned_count)
        vista_count = combined_records.count { |r| r['source'] == SourceConstants::VISTA }
        oh_count = combined_records.count { |r| r['source'] == SourceConstants::ORACLE_HEALTH }

        mr_log.diagnostic(
          resource: VACCINES, action: 'index',
          total_vaccines: returned_count, vista_raw: vista_count, oracle_health_raw: oh_count
        )

        StatsD.gauge("#{vaccines_statsd_prefix}.index.total", returned_count)
        StatsD.gauge("#{vaccines_statsd_prefix}.index.vista", vista_count)
        StatsD.gauge("#{vaccines_statsd_prefix}.index.oracle_health", oh_count)
      end

      # Always-on: warns when more than half of immunization records are dropped during parsing.
      def warn_vaccines_high_filter_rate(raw_count, returned_count, source_breakdown: {})
        return if raw_count.zero?

        filter_rate = 1.0 - (returned_count.to_f / raw_count)
        return unless filter_rate > HIGH_FILTER_RATE_THRESHOLD

        mr_log.warn(
          resource: VACCINES, action: 'index',
          anomaly: 'high_filter_rate',
          filter_rate: (filter_rate * 100).round(1),
          raw_count:, returned_count:,
          **source_breakdown
        )

        StatsD.increment("#{vaccines_statsd_prefix}.anomaly.high_filter_rate")
      end

      # Diagnostic: logs raw entry counts per source from SCDF before any filtering.
      # Helps distinguish "SCDF returned nothing" from "our filters dropped everything".
      def log_vaccines_raw_source_counts(body)
        return unless vaccines_logging_enabled?

        vista_count = body.dig(SourceConstants::VISTA, 'entry')&.size || 0
        oh_count = body.dig(SourceConstants::ORACLE_HEALTH, 'entry')&.size || 0

        mr_log.diagnostic(
          resource: VACCINES, action: 'index',
          stage: 'raw_from_scdf',
          vista_entry_count: vista_count,
          oracle_health_entry_count: oh_count,
          total_entry_count: vista_count + oh_count
        )
      end

      # Structured error log for get_immunizations failures — provides domain context for triage.
      def log_vaccines_error(error)
        mr_log.error(
          resource: VACCINES, action: 'index',
          error_class: error.class.name, error_message: error.message
        )
        StatsD.increment("#{vaccines_statsd_prefix}.error")
      end

      # Orchestrates index-level metrics and proactive warnings for get_immunizations.
      def log_vaccines_metrics(combined_records, parsed_vaccines)
        raw_count = combined_records.size
        returned_count = parsed_vaccines.size

        vista_raw = combined_records.count { |r| r['source'] == SourceConstants::VISTA }
        oh_raw = combined_records.count { |r| r['source'] == SourceConstants::ORACLE_HEALTH }
        source_breakdown = { vista_raw:, oracle_health_raw: oh_raw }

        vaccines_logging_enabled? && log_vaccines_response_count(raw_count, returned_count)
        vaccines_logging_enabled? && log_vaccines_index_metrics(combined_records, returned_count)
        warn_vaccines_high_filter_rate(raw_count, returned_count, source_breakdown:)
      end
    end
  end
end
