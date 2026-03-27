# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SavedClaimClaimantRepresentativePolicy < ApplicationPolicy
    def index?
      authorize
    end

    def show?
      authorize
    end

    private

    def authorize
      @user.representative?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        @scope.for_power_of_attorney_holders(
          @user.power_of_attorney_holders
        ).joins(:saved_claim)
      end
    end
  end
end
