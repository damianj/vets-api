# frozen_string_literal: true

# Shared helper methods for converting VA form data to IBM MMS VBA Data Dictionary format
# This concern provides reusable utilities for building standardized field mappings
# across multiple form types (21P-530A, 21-0779, 21-2680, 21-4192)
module IbmDataDictionary
  extend ActiveSupport::Concern

  # Build veteran basic identification fields
  # Common fields: VETERAN_FIRST_NAME, VETERAN_MIDDLE_INITIAL, VETERAN_LAST_NAME,
  #                VETERAN_SSN, VA_FILE_NUMBER, VETERAN_DOB
  # @param vet_info [Hash] Veteran information hash from parsed form
  # @param options [Hash] Optional field mappings for form-specific variations
  # @return [Hash] VBA Data Dictionary veteran fields
  def build_veteran_basic_fields(vet_info, _options = {})
    return {} unless vet_info

    {
      'VETERAN_FIRST_NAME' => vet_info.dig('fullName', 'first').to_s,
      'VETERAN_MIDDLE_INITIAL' => extract_middle_initial(vet_info.dig('fullName', 'middle')).to_s,
      'VETERAN_LAST_NAME' => vet_info.dig('fullName', 'last').to_s,
      'VETERAN_SSN' => vet_info['ssn'].to_s,
      'VA_FILE_NUMBER' => vet_info['vaFileNumber'].to_s,
      'VETERAN_DOB' => format_date_for_ibm(vet_info['dateOfBirth']).to_s
    }
  end

  # Build claimant identification fields
  # Common across forms 21-0779 and 21-2680
  # @param claimant_info [Hash] Claimant information hash
  # @return [Hash] VBA Data Dictionary claimant fields
  def build_claimant_fields(claimant_info)
    return {} unless claimant_info

    {
      'CLAIMANT_FIRST_NAME' => claimant_info.dig('fullName', 'first').to_s,
      'CLAIMANT_MIDDLE_INITIAL' => extract_middle_initial(claimant_info.dig('fullName', 'middle')).to_s,
      'CLAIMANT_LAST_NAME' => claimant_info.dig('fullName', 'last').to_s,
      'CLAIMANT_SSN' => claimant_info['ssn'].to_s,
      'CLAIMANT_DOB' => format_date_for_ibm(claimant_info['dateOfBirth']).to_s
    }
  end

  # Build full name from name hash components
  # Handles first, middle initial, and last name
  # @param name_hash [Hash, nil] Name components with 'first', 'middle', 'last' keys
  # @return [String] Formatted full name or empty string if no name provided
  def build_full_name(name_hash)
    return '' unless name_hash

    parts = [
      name_hash['first'],
      extract_middle_initial(name_hash['middle']),
      name_hash['last']
    ].compact.reject(&:empty?)

    parts.join(' ').strip.presence || ''
  end

  # Extract middle initial from middle name
  # @param middle_name [String, nil]
  # @return [String] First character or empty string
  def extract_middle_initial(middle_name)
    middle_name&.slice(0, 1) || ''
  end

  # Build full address string from address hash components
  # @param addr_hash [Hash, nil] Address with street, city, state, postalCode keys
  # @return [String] Formatted address or empty string if no address provided
  def build_full_address(addr_hash)
    return '' unless addr_hash

    parts = [
      addr_hash['street'],
      addr_hash['street2'],
      [addr_hash['city'], addr_hash['state']].compact.join(', '),
      addr_hash['postalCode']
    ].compact.reject(&:empty?)

    parts.join(' ').strip.presence || ''
  end

  # Build address fields hash for VBA Data Dictionary
  # @param addr_hash [Hash, nil] Address components
  # @param prefix [String] Field name prefix (e.g., 'CLAIMANT_ADDRESS', 'FACILITY_ADDRESS')
  # @return [Hash] VBA Data Dictionary address fields
  def build_address_fields(addr_hash, prefix)
    return {} unless addr_hash

    {
      "#{prefix}_LINE1" => addr_hash['street'].to_s,
      "#{prefix}_LINE2" => addr_hash['street2'].to_s,
      "#{prefix}_CITY" => addr_hash['city'].to_s,
      "#{prefix}_STATE" => addr_hash['state'].to_s,
      "#{prefix}_ZIP5" => addr_hash['postalCode'].to_s,
      prefix => build_full_address(addr_hash).to_s
    }
  end

  # Format date from YYYY-MM-DD to MM/DD/YYYY for IBM MMS
  # Per vendor specification, all forms use MM/DD/YYYY format with slashes
  # Example: "VETERAN_DOB": "10/19/1948"
  # @param date_string [String, nil] ISO 8601 date string (YYYY-MM-DD)
  # @param format [Symbol] Date format - :with_slashes (default) or :without_slashes
  # @return [String] Formatted date or empty string if invalid
  def format_date_for_ibm(date_string, format: :with_slashes)
    return '' unless date_string

    date = Date.parse(date_string)
    case format
    when :without_slashes
      date.strftime('%m%d%Y')
    else
      date.strftime('%m/%d/%Y')
    end
  rescue ArgumentError, TypeError
    ''
  end

  # Format phone number for IBM MMS
  # Preserves original formatting from form
  # @param phone_number [String, nil]
  # @return [String] Empty string if nil
  def format_phone_for_ibm(phone_number)
    return '' unless phone_number

    phone_number.strip.presence || ''
  end

  # Build checkbox value
  # Returns 1 for checked, 0 for unchecked (IBM MMS VBA Data Dictionary convention)
  # @param value [Boolean, nil]
  # @return [Integer]
  def build_checkbox_value(value)
    value == true ? 1 : 0
  end

  # Format currency value for IBM MMS
  # Formats with commas and 2 decimal places (no dollar sign)
  # @param amount [String, Integer, Float, nil] Numeric amount
  # @return [String] Formatted currency (e.g., "1,138.00") or empty string
  def format_currency_for_ibm(amount)
    return '' if amount.nil? || amount.to_s.strip.empty?

    numeric_value = amount.to_s.gsub(/[^0-9.]/, '').to_f
    format('%<amount>.2f', amount: numeric_value).gsub(/(\d)(?=(\d{3})+\.)/, '\1,')
  end

  # Build form metadata fields
  # @param form_type [String] VA form number (e.g., '21P-530a')
  # @param additional_fields [Hash] Form-specific metadata
  # @return [Hash] VBA Data Dictionary metadata fields
  def build_form_metadata(form_type, additional_fields = {})
    {
      'FORM_TYPE' => form_type
    }.merge(additional_fields).compact
  end
end
