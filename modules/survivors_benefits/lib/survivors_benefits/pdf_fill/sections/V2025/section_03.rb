# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    module V2025
      # Section 3: Veteran's Service Information
      class Section3 < Section
        KEY = {}.freeze
        def expand(form_data = {})
          form_data
        end
      end
    end
  end
end
