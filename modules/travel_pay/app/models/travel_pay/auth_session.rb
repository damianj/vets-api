# frozen_string_literal: true

module TravelPay
  class AuthSession
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :veis_token, :string
    attribute :btsss_token, :string
    attribute :contact_id, :string
  end
end
