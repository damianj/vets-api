# frozen_string_literal: true

require 'digital_forms_api/service/forms'
require 'digital_forms_api/service/submissions'

module DigitalFormsApi
  # The Fully Digital Forms controller that handles fetching form submissions and templates
  class SubmissionsController < ApplicationController
    service_tag 'digital-forms'

    before_action :check_flipper_flag

    # Fetch form submission and template from Forms API
    def show
      submission = submissions_service.retrieve(params[:id])
      unless veteran_id_authorized?(submission.body['envelope']['veteranId'])
        return render json: { error: 'Forbidden' }, status: :forbidden
      end

      template = forms_service.template('21-686c')
      render json: { submission: submission.body['envelope']['payload'],
                     template: template['formTemplate']['formTemplate']['21-686c'] }
    rescue Common::Client::Errors::ClientError => e
      if e.status == 404
        render json: { error: 'Not found' }, status: :not_found
      else
        Rails.logger.error('Digital Forms API - error status from BIP Forms API', { status: e.status })
        render json: { error: 'Internal server error' }, status: :internal_server_error
      end
    rescue => e
      Rails.logger.error('Digital Forms API - unexpected error', { message: e.message })
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end

    private

    def check_flipper_flag
      raise Common::Exceptions::Forbidden unless Flipper.enabled?(:dependents_digital_forms_api_submission_enabled,
                                                                  current_user)
    end

    # Instantiate service for interacting with the /forms endpoints
    def forms_service
      DigitalFormsApi::Service::Forms.new
    end

    # Instantiate service for interacting with the /submissions endpoints
    def submissions_service
      DigitalFormsApi::Service::Submissions.new
    end

    def veteran_id_authorized?(veteran_id)
      authorized = current_user&.participant_id.present? &&
                   veteran_id.is_a?(Hash) &&
                   veteran_id['identifierType'] == 'PARTICIPANTID' &&
                   veteran_id['value'] == current_user&.participant_id
      unless authorized
        Rails.logger.warn('Digital Form API - Veteran participant ID is forbidden to access this submission')
      end
      authorized
    end
  end
end
