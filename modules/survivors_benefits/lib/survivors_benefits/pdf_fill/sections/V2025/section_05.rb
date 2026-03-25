# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    module V2025
      class Section5 < Section
        KEY = {}.freeze
        def expand(form_data)
          form_data
        end
      end
    end
  end
end
