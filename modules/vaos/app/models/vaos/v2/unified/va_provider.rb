# frozen_string_literal: true

module VAOS
  module V2
    module Unified
      class VAProvider < BaseProvider
        attr_accessor :location_id, :facility_type, :scheduling_config

        def initialize(attrs = {})
          super
          self.provider_type = 'va'
        end

        # Builds a VAProvider from a Lighthouse Facility object
        # (FacilitiesApi::V2::Lighthouse::Facility)
        def self.from_lighthouse_facility(facility)
          new(
            id: facility.unique_id,
            location_id: facility.unique_id,
            name: facility.name,
            address: parse_lighthouse_address(facility.address),
            phone: facility.phone&.dig('main'),
            latitude: facility.lat,
            longitude: facility.long,
            facility_type: facility.facility_type,
            schedulable_services: parse_lighthouse_services(facility.services)
          )
        end

        def self.parse_lighthouse_address(address_hash)
          return nil if address_hash.blank?

          physical = address_hash['physical'] || address_hash[:physical]
          return nil if physical.blank?

          {
            street1: physical['address1'] || physical['address_1'],
            street2: physical['address2'] || physical['address_2'],
            street3: physical['address3'] || physical['address_3'],
            city: physical['city'],
            state: physical['state'],
            zip: physical['zip']
          }
        end

        def self.parse_lighthouse_services(services_hash)
          return [] if services_hash.blank?

          health = services_hash['health'] || services_hash[:health]
          return [] if health.blank?

          health.filter_map { |svc| svc['serviceId'] || svc['service_id'] || svc[:service_id] }
        end
      end
    end
  end
end
