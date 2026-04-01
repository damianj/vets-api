# frozen_string_literal: true

class ContactInformationSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :contact_information

  attribute :vet360_id do |object|
    object&.user&.vet360_id
  end

  attribute :va_profile_id do |object|
    object&.user&.vet360_id
  end

  attribute :email do |object|
    object&.email
  end

  attribute :residential_address do |object|
    object&.residential_address
  end

  attribute :mailing_address do |object|
    object&.mailing_address
  end

  attribute :mobile_phone do |object|
    object&.mobile_phone
  end

  attribute :home_phone do |object|
    object&.home_phone
  end

  attribute :work_phone do |object|
    object&.work_phone
  end

  attribute :temporary_phone do |object|
    object&.temporary_phone
  end

  attribute :fax_number do |object|
    object&.fax_number
  end

  attribute :contact_email_verified do |object|
    object&.email&.contact_email_verified?
  end
end
