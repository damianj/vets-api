# frozen_string_literal: true

module AskVAApi
  module V0
    class EducationFacilitiesController < GIDSController
      def autocomplete
        render json: service.get_institution_autocomplete_suggestions_v0(scrubbed_params)
      end

      def search
        # temporary mapping of physical_state field missing in v1 to preserve frontend expectation
        render json: AskVAApi::Adapters::InstitutionAdapter.search(service.get_institution_search_results_v1(scrubbed_params))
      end

      def show
        render json: AskVAApi::Adapters::InstitutionAdapter.details(service.get_institution_details_v1(scrubbed_params))
      end

      def children
        render json: service.get_institution_children_v0(scrubbed_params)
      end
    end
  end
end
