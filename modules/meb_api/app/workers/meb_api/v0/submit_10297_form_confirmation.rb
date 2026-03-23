# frozen_string_literal: true

require 'meb_api/v0/base_confirmation_email_worker'

module MebApi
  module V0
    class Submit10297FormConfirmation < BaseConfirmationEmailWorker
      FORM_TYPE = MebApi::ConfirmationEmailConfig::FORM_10297
      FORM_TAG = MebApi::ConfirmationEmailConfig::TAG_10297
    end
  end
end
