# frozen_string_literal: true

##
# Shared interface for VES form request models.
#
# This concern provides a common interface for determining form types across
# different VES request classes (VesRequest, VesOhiRequest, etc.).
#
# Including classes should override the relevant methods to return true
# for their specific form type.
#
# @example
#   class VesRequest
#     include VesFormModel
#
#     def form_1010d?
#       true
#     end
#   end
#
module VesFormModel
  extend ActiveSupport::Concern

  ##
  # Returns true if this is a 10-10D request (standalone, without subforms).
  #
  # @return [Boolean] false by default, override in implementing class
  def form_1010d?
    false
  end

  ##
  # Returns true if this is a 10-10D-EXTENDED request (10-10D with subforms).
  #
  # @return [Boolean] false by default, override in implementing class
  def form_1010dx?
    false
  end

  ##
  # Returns true if this is a 10-7959C (OHI) request.
  #
  # @return [Boolean] false by default, override in implementing class
  def form_7959c?
    false
  end
end
