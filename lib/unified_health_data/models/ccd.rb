# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Ccd
    include Vets::Model

    attribute :status, String
    attribute :job_id, String
    attribute :task_id, String
    attribute :source, String
    attribute :message, String
    attribute :retry_after_seconds, Integer
    attribute :authored_on, String
    attribute :xml, String
    attribute :html, String
    attribute :pdf, String
    attribute :http_status, Integer # Internal only to pass through to controller
  end
end
