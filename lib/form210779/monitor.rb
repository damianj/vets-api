# frozen_string_literal: true

require 'logging/committee_validation_monitor'

module Form210779
  ##
  # Monitor class for tracking Form 21-0779 validation and submission events
  #
  # Inherits from CommitteeValidationMonitor but uses ActiveRecord validation
  # instead of Committee middleware. Overrides track_request_validation_error
  # to handle ActiveRecord-specific validation errors.
  #
  class Monitor < ::Logging::CommitteeValidationMonitor
    SERVICE_NAME = 'form210779'
    FORM_ID = '21-0779'
    CLAIM_STATS_KEY = 'api.form210779'

    def initialize
      super(SERVICE_NAME)
    end

    # Required BaseMonitor abstract method implementations
    def claim_stats_key
      CLAIM_STATS_KEY
    end

    def name
      SERVICE_NAME
    end

    def form_id
      FORM_ID
    end

    ##
    # Logs validation failures from ActiveRecord
    #
    # Form 21-0779 does not use Committee middleware for validation.
    # This tracks ActiveRecord validation errors when claim.save fails.
    # Overrides the base class Committee validation implementation.
    #
    # Note: Rails handles malformed JSON at middleware level (returns 400),
    # so JSON parse errors never reach the controller.
    #
    # @param error [Common::Exceptions::ValidationErrors] The validation error
    # @param request [Rack::Request] The incoming request
    # @param claim [SavedClaim::Form210779] The claim object with validation errors
    def track_request_validation_error(error:, request:, claim: nil)
      validation_details = extract_validation_details_from_error(error, claim)

      submit_event(
        :warn,
        "#{message_prefix} validation failed: #{validation_details[:error_type]}",
        "#{CLAIM_STATS_KEY}.validation_error",
        form_id: FORM_ID,
        path: request.path,
        method: request.request_method,
        source_app: extract_source_app(request),
        error_type: validation_details[:error_type],
        data_pointer: validation_details[:data_pointer],
        validation_message: validation_details[:validation_message],
        tags: validation_error_tags(validation_details)
      )
    end

    private

    # Override hook methods for form-specific tags
    def validation_error_tags(_validation_details)
      ['action:create', 'status:validation_error']
    end

    def submission_begun_tags
      ['action:create', 'status:begun']
    end

    # ActiveRecord-specific validation error extraction
    # (used instead of Committee validation)

    ##
    # Extracts validation details from ActiveRecord errors without exposing PII
    #
    # @param error [Common::Exceptions::ValidationErrors] The validation error
    # @param claim [SavedClaim::Form210779] The claim object with validation errors
    # @return [Hash] Hash with :error_type, :data_pointer, and :validation_message
    def extract_validation_details_from_error(error, claim)
      # Debug log for local development (suppressed in production)
      Rails.logger.debug { "[#{self.class.name}] Validation error: #{error.class} - #{error.message}" }

      {
        error_type: 'activerecord_validation',
        data_pointer: extract_data_pointer_from_claim(claim),
        validation_message: extract_validation_message_from_claim(claim)
      }
    end

    ##
    # Extracts field path from ActiveRecord validation errors
    #
    # @param claim [SavedClaim::Form210779, nil] The claim object
    # @return [String] The field path or 'unknown'
    def extract_data_pointer_from_claim(claim)
      return 'unknown' unless claim&.errors&.any?

      # Get first error's attribute path
      first_error_key = claim.errors.attribute_names.first
      first_error_key.to_s.presence || 'unknown'
    end

    ##
    # Extracts validation error messages from ActiveRecord validation errors
    #
    # @param claim [SavedClaim::Form210779, nil] The claim object
    # @return [String] All validation error messages joined, or 'unknown'
    def extract_validation_message_from_claim(claim)
      return 'unknown' unless claim&.errors&.any?

      # Get all full error messages joined (e.g., "Veteran full name is required; Date of birth is invalid")
      claim.errors.full_messages.join('; ').presence || 'unknown'
    end
  end
end
