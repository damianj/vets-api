# frozen_string_literal: true

module VAOS
  module V2
    module Unified
      class ServiceTypeMapper
        LIGHTHOUSE_TO_VAOS = {
          'primaryCare' => 'primaryCare',
          'audiology' => 'audiology',
          'optometry' => 'optometry',
          'ophthalmology' => 'ophthalmology',
          'socialWork' => 'socialWork',
          'mentalHealth' => 'outpatientMentalHealth',
          'nutrition' => 'foodAndNutrition',
          'covid19Vaccine' => 'covid',
          'sleepMedicine' => 'homeSleepTesting',
          'weightManagement' => 'moveProgram',
          'pharmacy' => 'clinicalPharmacyPrimaryCare'
        }.freeze

        # Lighthouse sometimes returns PascalCase serviceIds (e.g. "Optometry" in facilities_api
        # serializer specs) while the map uses lowerCamelCase ("optometry"). We try an exact match
        # first, then the same string with only the first character lowercased so "primaryCare" is
        # unchanged but "Optometry" becomes "optometry". Full downcase would break "primaryCare".
        def self.to_vaos(lighthouse_service_id)
          return nil if lighthouse_service_id.blank?

          id = lighthouse_service_id.to_s.strip
          LIGHTHOUSE_TO_VAOS[id] || first_char_downcased_lookup(id)
        end

        def self.first_char_downcased_lookup(id)
          return nil if id.blank?

          LIGHTHOUSE_TO_VAOS[id[0].downcase + id[1..]]
        end
        private_class_method :first_char_downcased_lookup

        def self.schedulable_services(lighthouse_health_services)
          return [] if lighthouse_health_services.blank?

          lighthouse_health_services
            .filter_map { |service| to_vaos(service['serviceId']) }
            .uniq
        end
      end
    end
  end
end
