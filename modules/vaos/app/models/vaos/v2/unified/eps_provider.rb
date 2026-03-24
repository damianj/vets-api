# frozen_string_literal: true

module VAOS
  module V2
    module Unified
      class EpsProvider < BaseProvider
        attr_accessor :provider_service_id, :network_id, :npi, :specialties,
                      :digital_booking_features

        def initialize(attrs = {})
          super
          self.provider_type = 'community_care'
        end

        # Builds an EpsProvider from an EPS provider service response (Hash or OpenStruct)
        def self.from_eps_provider_service(provider)
          provider = provider.to_h if provider.is_a?(OpenStruct)
          location = provider[:location] || {}

          new(
            id: provider[:id],
            provider_service_id: provider[:id],
            name: provider[:name],
            address: parse_eps_address(location[:address]),
            phone: extract_phone(provider),
            latitude: location[:latitude],
            longitude: location[:longitude],
            npi: extract_npi(provider),
            specialties: provider[:specialties] || [],
            network_id: provider[:network_ids]&.first,
            digital_booking_features: provider[:features],
            schedulable_services: extract_specialties(provider[:specialties])
          )
        end

        def self.parse_eps_address(address_string)
          return nil if address_string.blank?

          # EPS addresses come as a single comma-separated string
          # e.g. "1105 Palmetto Ave, Melbourne, FL, 32901, US"
          parts = address_string.split(',').map(&:strip)
          {
            street1: parts[0],
            city: parts[1],
            state: parts[2],
            zip: parts[3]
          }
        end

        def self.extract_phone(provider)
          contacts = provider[:contact_details]
          return nil if contacts.blank?

          phone_contact = contacts.find { |c| c[:system] == 'phone' && c[:use] == 'for_patient' }
          phone_contact ||= contacts.find { |c| c[:system] == 'phone' }
          phone_contact&.dig(:value)
        end

        def self.extract_npi(provider)
          providers = provider[:individual_providers]
          return nil if providers.blank?

          providers.first&.dig(:npi)
        end

        def self.extract_specialties(specialties)
          return [] if specialties.blank?

          specialties.map { |s| s[:name] }.compact
        end
      end
    end
  end
end
