# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10272 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10272')

  def retention_period
    60.days
  end
end
