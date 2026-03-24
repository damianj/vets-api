# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA0976 < SavedClaim::EducationBenefits
  add_form_and_validation('22-0976')

  def retention_period
    60.days
  end
end
