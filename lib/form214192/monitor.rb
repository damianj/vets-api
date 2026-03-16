# frozen_string_literal: true

require 'logging/committee_validation_monitor'

module Form214192
  ##
  # Monitor class for tracking Form 21-4192 validation and submission events
  #
  # Inherits shared Committee validation and submission tracking from
  # Logging::CommitteeValidationMonitor. Overrides hook methods for
  # form-specific tag differences.
  class Monitor < ::Logging::CommitteeValidationMonitor
    SERVICE_NAME = 'form214192'
    FORM_ID = '21-4192'
    CLAIM_STATS_KEY = 'api.form214192'

    def initialize
      super(SERVICE_NAME)
    end

    # Required BaseMonitor abstract method implementations
    def claim_stats_key = CLAIM_STATS_KEY
    def name = SERVICE_NAME
    def form_id = FORM_ID

    private

    def validation_error_tags(validation_details)
      ['action:create', "error_type:#{validation_details[:error_type]}"]
    end
  end
end
