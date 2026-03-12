# frozen_string_literal: true

require 'logging/base_monitor'

module Form210779
  ##
  # Monitor class for tracking Form 21-0779 validation and submission events
  #
  # Provides methods for tracking validation failures and other
  # form-related events with StatsD metrics and structured logging.
  #
  class Monitor < ::Logging::BaseMonitor
    SERVICE_NAME = 'form210779'
    FORM_ID = '21-0779'
    CLAIM_STATS_KEY = 'api.form210779'

    # Parameters allowed in logs (no PII)
    ALLOWLIST = %w[
      action
      claim_guid
      code
      data_pointer
      duration_ms
      error_class
      error_message
      error_type
      method
      path
      source_app
      user_uuid
    ].freeze

    def initialize
      super(SERVICE_NAME, allowlist: ALLOWLIST)
    end

    ##
    # Logs validation failures from ActiveRecord
    #
    # Form 21-0779 does not use Committee middleware for validation.
    # This tracks ActiveRecord validation errors when claim.save fails.
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
        tags: ['action:create', 'status:validation_error']
      )
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
    # Track submission begun in controller
    # Called when submission processing starts, before validation and persistence
    #
    # @param claim [SavedClaim::Form210779]
    # @param user_uuid [String, nil] Optional user UUID for tracking
    def track_submission_begun(claim, user_uuid: nil)
      submit_event(
        :info,
        "#{message_prefix} submission begun",
        "#{CLAIM_STATS_KEY}.submission.begun",
        claim:,
        user_uuid:,
        claim_guid: claim&.guid,
        tags: ['action:create', 'status:begun']
      )
    end

    ##
    # Track successful submission
    # Called when claim is successfully validated, saved, and attachments processed
    #
    # @param claim [SavedClaim::Form210779]
    # @param user_uuid [String, nil] Optional user UUID for tracking
    def track_submission_success(claim, user_uuid: nil)
      submit_event(
        :info,
        "#{message_prefix} submission success",
        "#{CLAIM_STATS_KEY}.submission.success",
        claim:,
        user_uuid:,
        claim_guid: claim&.guid,
        tags: ['action:create', 'status:success']
      )
      track_request_code(200, action: 'create', user_uuid:, claim_guid: claim&.guid)
    end

    ##
    # Track submission failure
    # Called when claim validation or save fails in the controller action
    #
    # @param claim [SavedClaim::Form210779]
    # @param error [StandardError] The error that occurred
    # @param user_uuid [String, nil] Optional user UUID for tracking
    def track_submission_failure(claim, error, user_uuid: nil)
      submit_event(
        :error,
        "#{message_prefix} submission failure: #{error.class}",
        "#{CLAIM_STATS_KEY}.submission.failure",
        claim:,
        user_uuid:,
        claim_guid: claim&.guid,
        error_class: error.class.name,
        error_message: error.message,
        tags: ['action:create', 'status:failure']
      )
      status_code = infer_status_code(error)
      track_request_code(status_code, action: 'create', user_uuid:, claim_guid: claim&.guid)
    end

    ##
    # Track HTTP response codes for API endpoint monitoring
    # Enables response code distribution tracking in Datadog
    #
    # @param code [Integer] HTTP status code (200, 422, 429, 500, etc.)
    # @param action [String, nil] Optional action name
    #   (e.g., 'create', 'download_pdf')
    # @param user_uuid [String, nil] Optional user UUID for correlation
    # @param claim_guid [String, nil] Optional claim GUID for correlation
    def track_request_code(code, action: nil, user_uuid: nil, claim_guid: nil)
      submit_event(
        :info,
        "#{message_prefix} request completed with status #{code}",
        "#{CLAIM_STATS_KEY}.request",
        code:,
        action:,
        user_uuid:,
        claim_guid:,
        tags: ["status_code:#{code}", action ? "action:#{action}" : nil].compact
      )
    end

    ##
    # Track successful PDF generation with timing
    # Called when PDF is successfully generated and ready to send
    #
    # @param start_time [Time] When PDF generation started
    def track_pdf_generation_success(start_time, user_uuid: nil, claim_guid: nil)
      duration_ms = (Time.current - start_time) * 1000
      StatsD.measure("#{CLAIM_STATS_KEY}.pdf_generation.duration", duration_ms)

      submit_event(
        :info,
        "#{message_prefix} PDF generation success",
        "#{CLAIM_STATS_KEY}.pdf_generation.success",
        duration_ms:,
        user_uuid:,
        claim_guid:,
        tags: ['action:download_pdf', 'status:success']
      )
      track_request_code(200, action: 'download_pdf', user_uuid:, claim_guid:)
    end

    ##
    # Track PDF generation failure
    # Called when PDF generation fails at any stage
    #
    # @param error [Exception] The error that occurred
    def track_pdf_generation_failure(error, user_uuid: nil, claim_guid: nil)
      submit_event(
        :error,
        "#{message_prefix} PDF generation failure",
        "#{CLAIM_STATS_KEY}.pdf_generation.failure",
        error_class: error.class.name,
        error_message: error.message,
        user_uuid:,
        claim_guid:,
        tags: ['action:download_pdf', 'status:failure']
      )
      status_code = infer_status_code(error)
      track_request_code(status_code, action: 'download_pdf', user_uuid:, claim_guid:)
    end

    private

    def message_prefix
      "#{SERVICE_NAME}:#{FORM_ID}"
    end

    ##
    # Infers HTTP status code from error type
    #
    # @param error [Exception] The error that occurred
    # @return [Integer] HTTP status code
    def infer_status_code(error)
      case error
      when Common::Exceptions::ValidationErrors
        422
      when Common::Exceptions::RecordNotFound, ActiveRecord::RecordNotFound
        404
      else
        500
      end
    end

    ##
    # Extracts validation details from ActiveRecord errors without exposing PII
    #
    # @param error [Common::Exceptions::ValidationErrors] The validation error
    # @param claim [SavedClaim::Form210779] The claim object with validation errors
    # @return [Hash] Hash with :error_type and :data_pointer
    def extract_validation_details_from_error(error, claim)
      # Debug log for local development (suppressed in production)
      Rails.logger.debug { "[#{self.class.name}] Validation error: #{error.class} - #{error.message}" }

      {
        error_type: 'activerecord_validation',
        data_pointer: extract_data_pointer_from_claim(claim)
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
    # Extracts source app from request headers
    #
    # @param request [Rack::Request] The incoming request
    # @return [String] The source app name or 'unknown'
    def extract_source_app(request)
      request.env['SOURCE_APP'] || request.env['HTTP_X_SOURCE_APP'] || 'unknown'
    end
  end
end
