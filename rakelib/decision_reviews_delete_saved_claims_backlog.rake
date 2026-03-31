# frozen_string_literal: true

namespace :decision_reviews do
  desc 'One-off task to delete backlogged SavedClaim records in batches'
  task delete_saved_claims_backlog: :environment do
    dry_run = ENV['DRY_RUN'] != 'false'
    batch_size = (ENV['BATCH_SIZE'] || 2500).to_i
    batch_size = 2500 unless batch_size.positive?

    # Map short names to full class names
    type_mapping = {
      'hlr' => 'SavedClaim::HigherLevelReview',
      'nod' => 'SavedClaim::NoticeOfDisagreement',
      'sc' => 'SavedClaim::SupplementalClaim'
    }

    # TYPES is required - no default to prevent accidental deletion of all types
    unless ENV['TYPES']
      puts '❌ TYPES is required. Please specify which claim types to delete.'
      puts ''
      puts 'Valid options:'
      puts "  #{type_mapping.keys.join(', ')} (individual types)"
      puts '  all (all types - use with caution)'
      puts ''
      puts 'Examples:'
      puts '  TYPES=hlr,sc bundle exec rake decision_reviews:delete_saved_claims_backlog'
      puts '  TYPES=all DRY_RUN=false bundle exec rake decision_reviews:delete_saved_claims_backlog'
      next
    end

    # Parse TYPES env var (e.g., "hlr,sc" or "all")
    requested_types = ENV['TYPES'].downcase.split(',').map(&:strip)

    claim_types = if requested_types.include?('all')
                    type_mapping.values
                  else
                    requested_types.filter_map { |t| type_mapping[t] }
                  end

    if claim_types.empty?
      puts "❌ Invalid TYPES specified. Valid options: #{type_mapping.keys.join(', ')}, all"
      puts 'Example: TYPES=hlr,sc bundle exec rake decision_reviews:delete_saved_claims_backlog'
      next
    end

    scope = SavedClaim
            .where(type: claim_types)
            .where(delete_date: ..DateTime.now)

    total_count = scope.count

    puts '=' * 60
    puts 'Decision Reviews - Delete SavedClaims Backlog'
    puts '=' * 60
    puts "Mode: #{dry_run ? '🔍 DRY RUN' : '🚨 LIVE RUN'}"
    puts "Batch size: #{batch_size}"
    puts "Total records to delete: #{total_count}"
    puts "Claim types: #{claim_types.join(', ')}"
    puts '=' * 60

    if total_count.zero?
      puts '✅ No records to delete. Exiting.'
      next
    end

    if dry_run
      puts "\n⚠️  DRY RUN MODE - No records will be deleted"
      puts 'To perform actual deletion, run with:'
      puts "  DRY_RUN=false TYPES=#{requested_types.join(',')} bundle exec rake " \
           'decision_reviews:delete_saved_claims_backlog'

      puts "\nBreakdown by type:"
      claim_types.each do |type|
        count = scope.where(type:).count
        puts "  - #{type}: #{count}"
      end

      puts "\nEstimated time: ~#{(total_count / 10.8 / 60).round(1)} minutes (based on ~10.8 records/sec throughput)"
      puts "\n✅ Dry run complete. No changes made."
      next
    end

    puts "\n🚀 Starting deletion..."
    start_time = Time.current
    total_deleted = 0
    batch_number = 0

    scope.in_batches(of: batch_size) do |batch|
      batch_number += 1
      batch_start = Time.current

      deleted = batch.destroy_all.size
      total_deleted += deleted

      batch_duration = (Time.current - batch_start).round(2)
      elapsed = Time.current - start_time
      elapsed_display = elapsed.round(2)
      safe_elapsed = elapsed.positive? ? elapsed : 0.001
      rate = (total_deleted / safe_elapsed).round(1)

      puts "[Batch #{batch_number}] Deleted #{deleted} records " \
           "(Total: #{total_deleted}/#{total_count}) " \
           "[#{batch_duration}s batch, #{elapsed_display}s elapsed, #{rate} rec/sec]"
    end

    duration = Time.current - start_time
    duration_display = duration.round(2)
    safe_duration = duration.positive? ? duration : 0.001
    puts "\n#{'=' * 60}"
    puts '✅ Deletion complete!'
    puts "Total records deleted: #{total_deleted}"
    puts "Total time: #{duration_display} seconds (#{(duration / 60).round(2)} minutes)"
    puts "Average throughput: #{(total_deleted / safe_duration).round(1)} records/sec"
    puts '=' * 60
  end
end
