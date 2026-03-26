# frozen_string_literal: true

require 'json'
require 'common/client/base'
require 'ivc_champva/monitor'
require_relative 'configuration'

module IvcChampva
  module VesApi
    class VesApiError < StandardError; end

    # TODO: define Message response structure

    class Client < Common::Client::Base
      configuration IvcChampva::VesApi::Configuration

      def settings
        Settings.ivc_champva_ves_api
      end

      ##
      # Returns the OHI API key, falling back to the standard api_key if not configured
      #
      # @return [String] the API key for OHI requests
      def ohi_api_key
        settings.ohi_api_key.presence || settings.api_key
      end

      ##
      # HTTP POST call to the VES VFMP CHAMPVA Application service to submit a 10-10d application.
      #
      # @param transaction_uuid [string] the UUID for the transaction (sent in header)
      # @param ves_request_data [IvcChampva::VesRequest] preformatted request data
      def submit_1010d(transaction_uuid, ves_request_data)
        resp = connection.post("#{config.base_path}/ves-vfmp-app-svc/champva-applications") do |req|
          req.headers = headers(transaction_uuid, settings.api_key)
          req.body = ves_request_data.to_json
        end

        # Log with application_uuid (which equals form_uuid) for consistent tracking
        application_uuid = extract_application_uuid(ves_request_data)
        monitor.track_ves_response(application_uuid, resp.status, resp.body)

        raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200

        resp
      rescue => e
        raise VesApiError, e.message.to_s
      end

      ##
      # HTTP POST call to the VES VFMP service to submit a 10-7959c OHI certification.
      #
      # @param transaction_uuid [string] the UUID for the transaction (sent in header)
      # @param ves_request_data [IvcChampva::VesOhiRequest] preformatted request data
      # @return [Faraday::Response] the response from VES
      # @raise [VesApiError] if the response status is not 200
      def submit_7959c(transaction_uuid, ves_request_data)
        resp = connection.post("#{config.base_path}/ves-vfmp-app-svc/champva-insurance-form") do |req|
          req.headers = headers(transaction_uuid, ohi_api_key)
          req.body = ves_request_data.to_json
        end

        # Log with application_uuid (which equals form_uuid) for consistent tracking
        application_uuid = extract_application_uuid(ves_request_data)
        monitor.track_ves_response(application_uuid, resp.status, resp.body)

        raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200

        resp
      rescue => e
        raise VesApiError, e.message.to_s
      end

      ##
      # Assembles headers for VES API requests
      #
      # @param transaction_uuid [string] the transaction UUID
      # @param key [string] the API key to use
      # @return [Hash] the headers
      def headers(transaction_uuid, key)
        {
          :content_type => 'application/json',
          'apiKey' => key,
          'transactionUUId' => transaction_uuid.to_s
        }
      end

      ##
      # retreive a monitor for tracking
      #
      # @return [IvcChampva::Monitor]
      #
      def monitor
        @monitor ||= IvcChampva::Monitor.new
      end

      ##
      # Extracts application_uuid from the VES request data.
      # Handles both VesRequest objects (with accessor) and Hash objects (from retries).
      #
      # @param ves_request_data [VesRequest, VesOhiRequest, Hash] the request data
      # @return [String, nil] the application UUID
      def extract_application_uuid(ves_request_data)
        if ves_request_data.respond_to?(:application_uuid)
          ves_request_data.application_uuid
        elsif ves_request_data.is_a?(Hash)
          ves_request_data['application_uuid'] || ves_request_data['applicationUUID']
        end
      end
    end
  end
end
