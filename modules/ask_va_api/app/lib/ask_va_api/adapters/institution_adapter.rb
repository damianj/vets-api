# frozen_string_literal: true

module AskVAApi
  module Adapters
    class InstitutionAdapter
      def self.search(institutions)
        institutions[:data].each do |institution|
          # empty strings prevent frontend displaying 'undefined' in search results
          institution_attributes = institution[:attributes]
          physical_state = institution_attributes[:state] || ''
          physical_zip = ''

          institution_attributes.store(:physical_state, physical_state)
          institution_attributes.store(:physical_zip, physical_zip)
        end

        institutions
      end

      def self.details(institution_detail)
        institution_detail[:data][:attributes].store(:physical_zip, '')
        institution_detail
      end
    end
  end
end
