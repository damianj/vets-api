# frozen_string_literal: true

require 'logging/committee_validation_monitor'

module Form21p530a
  ##
  # Monitor class for tracking Form 21P-530A validation and submission events
  #
  # Inherits shared Committee validation and submission tracking from
  # Logging::CommitteeValidationMonitor. Overrides hook methods for
  # form-specific tag and context differences.
  class Monitor < ::Logging::CommitteeValidationMonitor
    SERVICE_NAME = 'form21p530a'
    FORM_ID = '21P-530A'
    CLAIM_STATS_KEY = 'api.form21p530a'

    def initialize
      super(SERVICE_NAME)
    end

    # Required BaseMonitor abstract method implementations
    def claim_stats_key = CLAIM_STATS_KEY
    def name = SERVICE_NAME
    def form_id = FORM_ID

    private

    def validation_error_tags(_validation_details)
      ['action:create', 'status:validation_error']
    end

    def validation_error_context(_validation_details)
      { form_id: FORM_ID }
    end

    def submission_begun_tags
      ['action:create', 'status:begun']
    end

    def pdf_success_context(duration_ms, user_uuid: nil, claim_guid: nil)
      { pdf_generation_duration_ms: duration_ms.round(2), user_uuid:, claim_guid: }
    end
  end
end
