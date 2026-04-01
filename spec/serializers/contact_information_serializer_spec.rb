# frozen_string_literal: true

require 'rails_helper'

describe ContactInformationSerializer, type: :serializer do
  subject { serialize(contact_info, serializer_class: described_class) }

  let(:user) { create(:user, vet360_id: '12345') }
  let(:email) { build_stubbed(:email) }
  let(:residential_address) { build_stubbed(:va_profile_address) }
  let(:mailing_address) { build_stubbed(:va_profile_address, :mailing) }
  let(:mobile_phone) { build_stubbed(:telephone) }
  let(:home_phone) { build_stubbed(:telephone, :home) }
  let(:work_phone) { build_stubbed(:telephone, :work) }
  let(:temporary_phone) { build_stubbed(:telephone, :temporary) }
  let(:fax_number) { build_stubbed(:telephone, :fax) }

  let(:contact_info) do
    instance_double(
      VAProfileRedis::V2::ContactInformation,
      user:,
      email:,
      residential_address:,
      mailing_address:,
      mobile_phone:,
      home_phone:,
      work_phone:,
      temporary_phone:,
      fax_number:
    )
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'sets the type to contact_information' do
    expect(data['type']).to eq 'contact_information'
  end

  it 'sets the id to empty string' do
    expect(data['id']).to eq ''
  end

  it 'includes :vet360_id' do
    expect(attributes['vet360_id']).to eq user.vet360_id
  end

  it 'includes :va_profile_id' do
    expect(attributes['va_profile_id']).to eq user.vet360_id
  end

  describe 'email' do
    it 'includes email id & address' do
      expect(attributes['email']['id']).to eq email.id
      expect(attributes['email']['email_address']).to eq email.email_address
    end
  end

  describe 'residential_address' do
    it 'includes all address attributes' do
      expect(attributes['residential_address']['address_line1']).to eq residential_address.address_line1
      expect(attributes['residential_address']['city']).to eq residential_address.city
      expect(attributes['residential_address']['zip_code']).to eq residential_address.zip_code
      expect(attributes['residential_address']['state_code']).to eq residential_address.state_code
      expect(attributes['residential_address']['address_pou']).to eq residential_address.address_pou
    end
  end

  describe 'mailing_address' do
    it 'includes all address attributes' do
      expect(attributes['mailing_address']['address_line1']).to eq mailing_address.address_line1
      expect(attributes['mailing_address']['city']).to eq mailing_address.city
      expect(attributes['mailing_address']['zip_code']).to eq mailing_address.zip_code
      expect(attributes['mailing_address']['state_code']).to eq mailing_address.state_code
      expect(attributes['mailing_address']['address_pou']).to eq mailing_address.address_pou
    end
  end

  describe 'mobile_phone' do
    it 'includes all phone attributes' do
      expect(attributes['mobile_phone']['phone_number']).to eq mobile_phone.phone_number
      expect(attributes['mobile_phone']['phone_type']).to eq mobile_phone.phone_type
      expect(attributes['mobile_phone']['area_code']).to eq mobile_phone.area_code
      expect(attributes['mobile_phone']['country_code']).to eq mobile_phone.country_code
    end
  end

  describe 'home_phone' do
    it 'includes all phone attributes' do
      expect(attributes['home_phone']['phone_number']).to eq home_phone.phone_number
      expect(attributes['home_phone']['phone_type']).to eq home_phone.phone_type
      expect(attributes['home_phone']['area_code']).to eq home_phone.area_code
      expect(attributes['home_phone']['country_code']).to eq home_phone.country_code
    end
  end

  describe 'work_phone' do
    it 'includes all phone attributes' do
      expect(attributes['work_phone']['phone_number']).to eq work_phone.phone_number
      expect(attributes['work_phone']['phone_type']).to eq work_phone.phone_type
      expect(attributes['work_phone']['area_code']).to eq work_phone.area_code
      expect(attributes['work_phone']['country_code']).to eq work_phone.country_code
    end
  end

  describe 'temporary_phone' do
    it 'includes all phone attributes' do
      expect(attributes['temporary_phone']['phone_number']).to eq temporary_phone.phone_number
      expect(attributes['temporary_phone']['phone_type']).to eq temporary_phone.phone_type
      expect(attributes['temporary_phone']['area_code']).to eq temporary_phone.area_code
      expect(attributes['temporary_phone']['country_code']).to eq temporary_phone.country_code
    end
  end

  describe 'fax_number' do
    it 'includes all phone attributes' do
      expect(attributes['fax_number']['phone_number']).to eq fax_number.phone_number
      expect(attributes['fax_number']['phone_type']).to eq fax_number.phone_type
      expect(attributes['fax_number']['area_code']).to eq fax_number.area_code
      expect(attributes['fax_number']['country_code']).to eq fax_number.country_code
    end
  end

  it 'includes :contact_email_verified' do
    expect(attributes['contact_email_verified']).to eq email.contact_email_verified?
  end
end
