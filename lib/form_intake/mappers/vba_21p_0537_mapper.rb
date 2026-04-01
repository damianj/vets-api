# frozen_string_literal: true

module FormIntake
  module Mappers
    # Mapper for form 21P-0537 (Application for Pension Benefits - Report of Remarriage)
    # Follows IBM Data Dictionary format (matches BioHeart implementation)
    class VBA21p0537Mapper < BaseMapper
      # rubocop:disable Metrics/MethodLength
      def to_gcio_payload
        form = form_data.with_indifferent_access

        {
          # 1A - Have you remarried since the death of the veteran?
          'REMARRIED_AFTER_VET_DEATH_YES' => remarried_yes?(form),
          'REMARRIED_AFTER_VET_DEATH_NO' => remarried_no?(form),

          # 1B - Date of Marriage
          'DATE_OF_MARRIAGE' => map_date(form.dig('remarriage', 'date_of_marriage')),

          # 1C - Name of Spouse
          'SPOUSE_NAME' => build_full_name(form.dig('remarriage', 'spouse_name')),
          'SPOUSE_FIRST_NAME' => form.dig('remarriage', 'spouse_name', 'first'),
          'SPOUSE_MIDDLE_INITIAL' => extract_middle_initial(form.dig('remarriage', 'spouse_name')),
          'SPOUSE_LAST_NAME' => form.dig('remarriage', 'spouse_name', 'last'),

          # 1D - Spouse Date of Birth
          'SPOUSE_DATE_OF_BIRTH' => map_date(form.dig('remarriage', 'spouse_date_of_birth')),

          # 1E - Is your spouse a Veteran?
          'SPOUSE_VET_YES' => spouse_veteran_yes?(form),
          'SPOUSE_VET_NO' => spouse_veteran_no?(form),

          # 1F - VA Claim Number or SSN
          'VA_CLAIM_NUMBER' => form.dig('remarriage', 'spouse_va_file_number').presence,
          'SSN' => map_ssn(form.dig('remarriage', 'spouse_ssn')),

          # 1G - What was your age at the time of your Marriage?
          'MARRIAGE_AGE' => form.dig('remarriage', 'age_at_marriage'),

          # 2A - Has Your Remarriage been Terminated?
          'MARR_TERM_YES' => marriage_terminated_yes?(form),
          'MARR_TERM_NO' => marriage_terminated_no?(form),

          # 2B - Date of Termination
          'MARR_TERM_DATE' => map_date(form.dig('remarriage', 'termination_date')),

          # 2C - Reason for Termination
          'MARR_TERM_REASON' => form.dig('remarriage', 'termination_reason'),

          # 3A - Daytime Telephone Number
          'DAY_PHONE' => map_phone(form.dig('recipient', 'phone', 'daytime')),

          # 3B - Evening Telephone Number
          'EVENING_PHONE' => map_phone(form.dig('recipient', 'phone', 'evening')),

          # 4 - Email Address
          'EMAIL' => form.dig('recipient', 'email'),

          # 5A - Signature
          'SIGNATURE' => form.dig('recipient', 'signature'),

          # 5B - Date Signed
          'DATE_SIGNED' => map_date(form.dig('recipient', 'signature_date')),

          # Form Type (must be prefixed with StructuredData: to be ingested)
          'FORM_TYPE' => 'StructuredData:21P-0537'
        }.transform_values { |v| v.nil? ? '' : v }
      end
      # rubocop:enable Metrics/MethodLength

      private

      def remarried_yes?(form)
        form['has_remarried'] == true
      end

      def remarried_no?(form)
        form['has_remarried'] == false
      end

      def spouse_veteran_yes?(form)
        form.dig('remarriage', 'spouse_is_veteran') == true
      end

      def spouse_veteran_no?(form)
        form.dig('remarriage', 'spouse_is_veteran') == false
      end

      def marriage_terminated_yes?(form)
        form.dig('remarriage', 'has_terminated') == true
      end

      def marriage_terminated_no?(form)
        form.dig('remarriage', 'has_terminated') == false
      end

      def build_full_name(name_hash)
        return nil unless name_hash

        parts = [
          name_hash['first'],
          name_hash['middle'],
          name_hash['last']
        ].compact.compact_blank

        parts.any? ? parts.join(' ') : nil
      end

      def extract_middle_initial(name_hash)
        return nil unless name_hash && name_hash['middle'].present?

        name_hash['middle'][0]
      end
    end
  end
end
