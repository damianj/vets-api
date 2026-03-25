# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    module V2025
      # Section 7: Dependency and Indemnity Compensation (D.I.C.)
      class Section7 < Section
        KEY = {}.freeze
        def expand(form_data)
          form_data
        end
      end
    end
  end
end
