# frozen_string_literal: true

module UnifiedHealthData
  module Adapters
    # Shared renewal-window logic used by both VistA and Oracle Health adapters.
    #
    # Include this module and call `within_renewal_window_days?(time)` with a
    # Time to check whether the prescription expired within the
    # RENEWAL_WINDOW_DAYS threshold.
    module RenewalWindow
      RENEWAL_WINDOW_DAYS = 120

      # Checks whether +expiration_time+ falls within the renewal window.
      # A prescription is within the window when it expired no more than
      # RENEWAL_WINDOW_DAYS ago (or has not yet expired).
      #
      # @param expiration_time [Time] expiration timestamp to check
      # @return [Boolean]
      def within_renewal_window_days?(expiration_time)
        return false if expiration_time.nil?

        expiration_time >= RENEWAL_WINDOW_DAYS.days.ago
      end
    end
  end
end
