# frozen_string_literal: true

require 'logging/monitor'

module DigitalFormsApi
  # Monitor for Digital Forms API
  class Monitor < Logging::Monitor
    # create a monitor
    #
    # @param allowlist [Array<String>] list of allowed params
    def initialize(allowlist = [])
      super('digital-forms-api', allowlist:)
    end

    # utility function, @see Rails.logger
    #
    # @param msg [Mixed] the message to be logged
    #
    # @return [String] the formatted message, preceded with the monitor class name
    def format_message(msg)
      format('%<class>s: %<msg>s', { class: self.class.name, msg: msg.to_s })
    end

    # utility function to format metric tags for DataDog
    #
    # @param tag_hash [Hash] key-value pairs for metric tags
    #
    # @return [Array<String>] an array of string; eg. ["key:value" ...]
    def format_tags(tag_hash)
      tag_hash.map { |key, value| "#{key}:#{value}" }
    end

    # Monitor to be used within Service classes
    class Service < Monitor
      # StatsD metric
      METRIC = 'module.digital_forms_api.service.request'
      # allowed logging params
      ALLOWLIST = %w[
        claim_label
        code
        duration
        endpoint
        ep_code
        form_id
        method
        reason
      ].freeze

      def initialize
        super(ALLOWLIST)
      end

      # track the api request performed and the response/error
      # @see Common::Client::Base#perform
      # @see Common::Client::Errors::ClientError
      #
      # @param method [String|Symbol] eg. get, post, put
      # @param endpoint [String] the requested service endpoint
      # @param code [Integer|String] the response code
      # @param reason [String] the response `reason_phrase` or the error message
      # @param duration [Integer] the duration of the request in milliseconds
      # @param call_location [Logging::CallLocation|Thread::Backtrace::Location] calling point to be logged
      def track_api_request(method, endpoint, code, reason, duration, call_location: nil, **context) # rubocop:disable Metrics/ParameterLists
        call_location ||= caller_locations.first

        message = format_message("#{code} #{reason}")
        tags = { method:, code:, endpoint: }.merge(context[:tags] || {})
        context = { method:, code:, endpoint:, reason:, duration: }.merge(context)
        context.delete(:tags) # avoid overwriting the tags arg to `track_request`

        level = /^2\d\d$/.match?(code.to_s.strip) ? :info : :error

        StatsD.measure("#{METRIC}.duration", duration, tags:)
        track_request(level, message, METRIC, call_location:, tags: format_tags(tags), **context)
      end
    end
  end
end
