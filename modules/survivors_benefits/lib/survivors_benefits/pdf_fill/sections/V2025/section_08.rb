# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    module V2025
      # Section VIII: Nursing Home or Increased Survivors Entitlement
      class Section8 < Section
        # Section configuration hash
        KEY = {}.freeze
        def expand(form_data = {})
          form_data
        end
      end
    end
  end
end
