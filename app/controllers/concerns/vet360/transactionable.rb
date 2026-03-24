# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'va_profile/contact_information/v2/service'

module Vet360
  module Transactionable
    extend ActiveSupport::Concern

    # Fetches and refreshes a VA Profile async transaction for the requested
    # transaction_id, then renders the serialized result as JSON.
    #
    # This concern is shared by multiple profile controllers. If the transaction
    # cannot be found for the current user, ActiveRecord raises RecordNotFound
    # from the model lookup; we remap that to Common::Exceptions::RecordNotFound
    # so the API responds with a 404 (instead of falling through to a generic 500).
    def check_transaction_status!
      transaction = AsyncTransaction::VAProfile::Base.refresh_transaction_status(
        @current_user,
        service,
        params[:transaction_id]
      )

      render json: AsyncTransaction::BaseSerializer.new(transaction).serializable_hash
    rescue ActiveRecord::RecordNotFound
      raise Common::Exceptions::RecordNotFound, params[:transaction_id]
    end

    private

    def service
      VAProfile::ContactInformation::V2::Service.new @current_user
    end
  end
end
