# frozen_string_literal: true

module V0
  module Profile
    class ContactInformationsController < ApplicationController
      service_tag 'profile'
      before_action { authorize :vet360, :access? }

      def show
        contact_info = current_user.vet360_contact_info
        render json: ContactInformationSerializer.new(contact_info)
      end
    end
  end
end
