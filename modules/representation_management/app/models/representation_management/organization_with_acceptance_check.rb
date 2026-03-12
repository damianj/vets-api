# frozen_string_literal: true

module RepresentationManagement
  class OrganizationWithAcceptanceCheck < SimpleDelegator
    def initialize(organization, eligible_poas:)
      super(organization)
      @eligible_poas = eligible_poas
    end

    def can_accept_digital_poa_requests
      return false unless __getobj__.can_accept_digital_poa_requests

      @eligible_poas.include?(__getobj__.poa)
    end

    def self.eligible_poas_for(organizations)
      poas = organizations.map(&:poa)
      Veteran::Service::OrganizationRepresentative.active
                                                  .where(organization_poa: poas,
                                                         acceptance_mode: 'any_request')
                                                  .distinct
                                                  .pluck(:organization_poa)
                                                  .to_set
    end
  end
end
