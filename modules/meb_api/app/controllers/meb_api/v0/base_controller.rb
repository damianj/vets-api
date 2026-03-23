# frozen_string_literal: true

require 'dgi/claimant/service'
require 'dgi/letters/service'
require 'dgi/status/service'
require 'meb_api/confirmation_email_config'

module MebApi
  module V0
    class BaseController < ::ApplicationController
      service_tag 'education-benefits'
      before_action :authorize_access

      STATS_KEY = 'api.meb.confirmation_email'

      private

      def authorize_access
        authorize(current_user, :access?, policy_class: MebPolicy)
      end

      def claim_status_service
        MebApi::DGI::Status::Service.new(@current_user)
      end

      def claim_letters_service
        MebApi::DGI::Letters::Service.new(@current_user)
      end

      def claimant_service
        MebApi::DGI::Claimant::Service.new(@current_user)
      end

      # Shared confirmation email logging methods
      def log_confirmation_email_request(form_tag, flipper_key)
        Rails.logger.info(
          'MEB confirmation email endpoint called',
          {
            form_tag:,
            flipper_enabled: Flipper.enabled?(flipper_key),
            params_claim_status: params[:claim_status],
            params_email_present: params[:email].present?,
            user_email_present: @current_user.email.present?
          }
        )
      end

      def log_confirmation_email_skipped(form_tag, reason, status = nil)
        Rails.logger.warn(
          'MEB confirmation email skipped',
          {
            form_tag:,
            reason:,
            claim_status: status
          }.compact
        )
        StatsD.increment("#{STATS_KEY}.skipped", tags: [form_tag, "reason:#{reason}"])
      end

      def validate_confirmation_email_attributes(form_tag)
        claim_status = params[:claim_status]
        email = params[:email] || @current_user.email
        first_name = params[:first_name]&.upcase || @current_user.first_name&.upcase

        if email.blank?
          log_confirmation_email_skipped(form_tag, 'email_missing', claim_status)
          return nil
        end

        unless claim_status.present? && first_name.present?
          log_confirmation_email_skipped(form_tag, 'missing_attributes', claim_status)
          return nil
        end

        { claim_status:, email:, first_name: }
      end

      def log_confirmation_email_dispatched(form_tag, status)
        normalized_status = MebApi::ConfirmationEmailConfig.normalize_claim_status(status)
        Rails.logger.info(
          'MEB confirmation email worker dispatched',
          {
            form_tag:,
            claim_status: status
          }
        )
        StatsD.increment("#{STATS_KEY}.dispatched",
                         tags: [form_tag, "claim_status:#{normalized_status}"])
      end

      def log_submission_error(error, log_message)
        cached_error_class = error.class.name
        cached_response_body = error.body if error.respond_to?(:body)

        log_params = {
          icn: @current_user.icn,
          error_class: cached_error_class,
          error_message: error.message.presence || 'No error message provided',
          request_id: request.request_id
        }

        # Only log response details for ClientError (downstream service failures).
        # Response body truncated to 250 chars to limit log size while preserving debug context.
        if error.is_a?(Common::Client::Errors::ClientError)
          log_params[:status] = error.status
          log_params[:response_body] = cached_response_body&.to_s&.truncate(250) if cached_response_body.present?
        end

        Rails.logger.error(log_message, log_params)

        # Increment metrics for monitoring/alerting
        StatsD.increment('api.meb.submit_claim.error', tags: ["error_class:#{cached_error_class}"])
      end
    end
  end
end
