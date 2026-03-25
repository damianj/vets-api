# frozen_string_literal: true

require 'logging/base_monitor'

module Logging
  ##
  # Base monitor for forms using Committee validation
  #
  # Provides shared tracking for submission lifecycle, request codes,
  # PDF generation, and Committee validation error extraction.
  # Used by Form214192::Monitor and Form21p530a::Monitor.
  # Form-specific monitors inherit from this and implement constants
  # plus small hook methods for form-specific tag/context differences.
  class CommitteeValidationMonitor < ::Logging::BaseMonitor
    # Parameters allowed in logs (no PII)
    # Union of all form-specific allowlists
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
      pdf_generation_duration_ms
      source_app
      user_uuid
      validation_message
    ].freeze

    def initialize(service, allowlist: [])
      super(service, allowlist: ALLOWLIST + allowlist)
    end

    ##
    # Logs Committee request validation failures
    #
    # Called when Committee middleware rejects a request that doesn't conform
    # to the OpenAPI schema. Logs the field path and error type without PII.
    #
    # @param error [Committee::InvalidRequest] The validation error from Committee
    # @param request [Rack::Request] The incoming request
    def track_request_validation_error(error:, request:)
      validation_details = extract_validation_details(error)

      submit_event(
        :warn,
        "#{message_prefix} Committee validation failed",
        "#{claim_stats_key}.validation_error",
        path: request.path,
        method: request.request_method,
        source_app: extract_source_app(request),
        error_type: validation_details[:error_type],
        data_pointer: validation_details[:data_pointer],
        validation_message: validation_details[:validation_message],
        **validation_error_context(validation_details),
        tags: validation_error_tags(validation_details)
      )
    end

    ##
    # Track submission begun in controller
    # Called when submission processing starts, before validation and persistence
    def track_submission_begun(claim, user_uuid: nil)
      submit_event(
        :info,
        "#{message_prefix} submission begun",
        "#{claim_stats_key}.submission.begun",
        claim:,
        user_uuid:,
        claim_guid: claim&.guid,
        tags: submission_begun_tags
      )
    end

    ##
    # Track successful submission in controller
    # Called when claim is successfully validated, saved,
    # and attachments processed
    def track_submission_success(claim, user_uuid: nil)
      submit_event(
        :info,
        "#{message_prefix} submission success",
        "#{claim_stats_key}.submission.success",
        claim:,
        user_uuid:,
        claim_guid: claim&.guid,
        tags: ['action:create', 'status:success']
      )
      track_request_code(200, action: 'create', user_uuid:, claim_guid: claim&.guid)
    end

    ##
    # Track submission failure in controller
    # Called when claim validation or save fails in the controller action
    def track_submission_failure(claim, error, user_uuid: nil)
      submit_event(
        :error,
        "#{message_prefix} submission failure: #{error.class}",
        "#{claim_stats_key}.submission.failure",
        claim:,
        user_uuid:,
        claim_guid: claim&.guid,
        error_class: error.class.name,
        error_message: error.message,
        tags: submission_failure_tags(error)
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
        "#{claim_stats_key}.request",
        code:,
        action:,
        user_uuid:,
        claim_guid:,
        tags: ["status_code:#{code}", action ? "action:#{action}" : nil].compact
      )
    end

    ##
    # Track PDF generation success with timing
    #
    # @param start_time [Time] When PDF generation started
    # @param user_uuid [String, nil] Optional user UUID for correlation
    # @param claim_guid [String, nil] Optional claim GUID for correlation
    def track_pdf_generation_success(start_time, user_uuid: nil, claim_guid: nil)
      duration_ms = (Time.current - start_time) * 1000
      StatsD.measure("#{claim_stats_key}.pdf_generation.duration", duration_ms)

      submit_event(
        :info,
        "#{message_prefix} PDF generation success",
        "#{claim_stats_key}.pdf_generation.success",
        **pdf_success_context(duration_ms, user_uuid:, claim_guid:),
        tags: ['action:download_pdf', 'status:success']
      )
      track_request_code(200, action: 'download_pdf', user_uuid:, claim_guid:)
    end

    ##
    # Track PDF generation failure
    #
    # @param error [Exception] The error that occurred
    # @param user_uuid [String, nil] Optional user UUID for correlation
    # @param claim_guid [String, nil] Optional claim GUID for correlation
    def track_pdf_generation_failure(error, user_uuid: nil, claim_guid: nil)
      submit_event(
        :error,
        "#{message_prefix} PDF generation failure: #{error.class}",
        "#{claim_stats_key}.pdf_generation.failure",
        error_class: error.class.name,
        error_message: error.message,
        user_uuid:,
        claim_guid:,
        tags: pdf_failure_tags(error)
      )
      status_code = infer_status_code(error)
      track_request_code(status_code, action: 'download_pdf', user_uuid:, claim_guid:)
    end

    private

    # @return [String] Prefix for log messages (e.g., "form214192:21-4192")
    def message_prefix = "#{name}:#{form_id}"

    # --- Hook methods for subclass customization ---

    # Tags for validation error events. Override in subclasses.
    # @return [Array<String>]
    def validation_error_tags(_validation_details)
      ['action:create']
    end

    # Extra context for validation error events. Override in subclasses.
    # @return [Hash]
    def validation_error_context(_validation_details)
      {}
    end

    # Tags for submission begun events. Override in subclasses.
    # @return [Array<String>]
    def submission_begun_tags
      ['action:create']
    end

    # Tags for submission failure events. Override in subclasses.
    # @return [Array<String>]
    def submission_failure_tags(_error)
      ['action:create', 'status:failure']
    end

    # Tags for PDF generation failure events. Override in subclasses.
    # @return [Array<String>]
    def pdf_failure_tags(_error)
      ['action:download_pdf', 'status:failure']
    end

    # Context payload for PDF generation success. Override to customize
    # the duration key name, rounding, or additional fields.
    # @return [Hash]
    def pdf_success_context(duration_ms, user_uuid: nil, claim_guid: nil)
      { duration_ms:, user_uuid:, claim_guid: }
    end

    # --- Shared private methods ---

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

    # Extracts error type and data pointer from a Committee validation error
    #
    # @param error [Committee::InvalidRequest] The validation error
    # @return [Hash] Hash with :error_type, :data_pointer, and :validation_message keys
    def extract_validation_details(error)
      message = error.message.to_s

      {
        error_type: extract_error_type(message),
        data_pointer: extract_data_pointer(message),
        validation_message: message
      }
    end

    ##
    # Extracts the error type from Committee error message
    #
    # @param message [String] The error message
    # @return [String] The error type (e.g., 'pattern', 'required', 'type')
    def extract_error_type(message)
      case message
      when /pattern.*does not match/i
        'pattern_mismatch'
      when /required/i
        'missing_required'
      when /is not a member of enum/i
        'invalid_enum'
      when /expected.*got/i, /type mismatch/i
        'type_mismatch'
      when /minimum|maximum/i
        'out_of_range'
      when /minLength|maxLength/i
        'invalid_length'
      else
        'validation_error'
      end
    end

    ##
    # Extracts the field path (data pointer) from Committee error message
    #
    # Removes PII by extracting only the schema path, not user values.
    #
    # @param message [String] The error message
    # @return [String, nil] The field path or nil if not found
    def extract_data_pointer(message)
      # Committee errors often include the path in formats like:
      # "#/properties/veteranInformation/properties/ssn pattern..."
      # or "/veteranInformation/ssn"
      if (match = message.match(%r{#/[^\s]+|/[a-zA-Z][a-zA-Z0-9/]*}))
        # Clean up the path to remove schema-specific parts
        path = match[0]
        path = path.gsub(%r{#/paths/[^/]+/[^/]+/requestBody/content/[^/]+/schema}, '')
        path = path.gsub('/properties/', '/')
        path = path.gsub(%r{^/+}, '/')
        path.presence || 'unknown'
      else
        'unknown'
      end
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
