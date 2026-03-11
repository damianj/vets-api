# frozen_string_literal: true

module VAOS
  module OhMigrationsHelper
    # Retrieves and builds a hash of migrations from the configured settings.
    #
    # Reads Settings.mhv.oh_facility_checks.oh_migrations_list, which is expected to be
    # a semicolon-separated list of migration entry strings. If the setting is nil,
    # empty, or only whitespace, the method returns an empty Hash.
    #
    # @return [Hash] the constructed migrations hash, or an empty hash if no valid entries.
    # @example
    # {
    #   '987': {
    #     migration_days: 30,
    #     migration_date: '2026-02-11',
    #     disable_eligibility: true,
    #     cancellation_disabled: true
    #   },
    #   '123': {
    #     migration_days: 30,
    #     migration_date: '2026-05-01',
    #     disable_eligibility: false,
    #     cancellation_disabled: false
    #   }
    # }
    def self.get_migrations
      raw_value = Settings.mhv.oh_facility_checks.oh_migrations_list

      return {} if raw_value.to_s.strip.blank?

      migrations = {}
      today = Time.use_zone('Eastern Time (US & Canada)') { Date.current }

      raw_value.to_s.split(';').filter_map do |migration_entry_string|
        migration_entry_string = migration_entry_string.strip
        next if migration_entry_string.blank?

        migration_entry = MigrationUtils.parse_single_migration_entry(migration_entry_string)

        MigrationUtils.build_migrations(migrations, migration_entry, today)
      end

      migrations
    end

    module MigrationUtils
      def self.build_migrations(migrations, migration_entry, today)
        migration_entry[:facilities].each do |facility|
          parent_facility = facility[:facility_id][0, 3]
          migration_days = (today - migration_entry[:migration_date]).to_i

          migration = {
            migration_days:,
            migration_date: migration_entry[:migration_date]
          }

          check_eligibility_override(migration, migration_days)
          check_cancellation_override(migration, migration_days)

          migrations[parent_facility] = migration
        end
        migrations = {}
      end

      def self.check_eligibility_override(migration, migration_days)
        is_minus30 = migration_days >= -30
        is_plus7 = migration_days >= 7

        # eligibility is disabled from 30 days before to 7 days after the migration date
        migration[:disable_eligibility] = is_minus30 && !is_plus7
      end

      def self.check_cancellation_override(migration, migration_days)
        is_minus10 = migration_days >= -10
        is_plus7 = migration_days >= 7

        # appointment cancellation is disabled from 10 days before to 7 days after the migration date
        migration[:cancellation_disabled] = is_minus10 && !is_plus7
      end

      def self.parse_single_migration_entry(entry)
        date_part, facilities_part = entry.split(':', 2)
        return nil if date_part.blank? || facilities_part.blank?

        facilities = parse_facilities_from_string(facilities_part)
        return nil if facilities.empty?

        {
          migration_date: Time.use_zone('Eastern Time (US & Canada)') { Date.parse(date_part.strip) },
          facilities:
        }
      end

      # Parses facilities from bracket-delimited string like "[123,Facility A],[456,Facility B]"
      def self.parse_facilities_from_string(facilities_string)
        facilities_string.scan(/\[([^\]]+)\]/).filter_map do |match|
          parts = match[0].split(',', 2)
          next if parts.length < 2 || parts[0].blank?

          {
            facility_id: parts[0].strip,
            facility_name: parts[1]&.strip || ''
          }
        end
      end
    end
  end
end
