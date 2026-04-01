# frozen_string_literal: true

require 'digital_forms_api/service/base'

module DigitalFormsApi
  module Service
    # Submissions API
    class Submissions < Base
      # POST submit form structured data
      #
      # @param payload [Hash] the validated form data; @see SavedClaim.parsed_form
      # @param metadata [Hash] required fields in addition to payload
      # @option metadata [String] :formId the form identifier, eg. '21-686c'; required
      # @option metadata [String] :veteranId the participant id of the veteran; required
      # @option metadata [String] :claimantId the participant id of the claimant; default to veteranId
      # @option metadata [String] :epCode the ep code; required
      # @option metadata [String] :claimLabel the claim label; required
      # @param dry_run [Boolean] perform a dry run in which no action is taken except validation by the endpoint
      def submit(payload, metadata, dry_run: false)
        transformed = {
          claimantId: { identifierType: 'PARTICIPANTID', value: metadata[:claimantId] || metadata[:veteranId] },
          veteranId: { identifierType: 'PARTICIPANTID', value: metadata[:veteranId] },
          payload:
        }

        # TODO: validate the request structure (future)
        request = { envelope: metadata.merge(transformed) }

        headers = {}

        # @see DigitalFormsApi::Service::Base#context
        tags = {
          form_id: metadata[:formId],
          ep_code: metadata[:epCode],
          claim_label: metadata[:claimLabel]
        }
        @context = tags.merge(tags:)

        perform :post, "submissions?dry-run=#{dry_run}", request, headers
      end

      # GET get a form submission
      def retrieve(submission_id)
        perform :get, "submissions/#{submission_id}", {}, {}
      end

      # GET get a form submission by document id
      # Retrieve details for a previously submitted form using the associated CE document ID
      def by_document_id(document_id)
        perform :get, "submissions/by-document-id/#{document_id}", {}, {}
      end

      private

      # @see DigitalFormsApi::Service::Base#endpoint
      def endpoint
        'submissions'
      end

      # end Submissions
    end

    # end Service
  end

  # end DigitalFormsApi
end
