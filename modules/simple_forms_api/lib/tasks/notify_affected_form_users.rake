# frozen_string_literal: true

# lib/tasks/notify_affected_form_users.rake
#
# One-off rake task to notify users affected by the _is_valid bug
# in InProgressForm data.
#
# Usage:
#   How I'm going to invoke this ->
# load 'modules/simple_forms_api/lib/tasks/notify_affected_form_users.rake'
# affected_users = collect_affected_users
# puts "Found #{affected_users.count} users"
# enqueue_notifications(affected_users, template_id: 'your-template-id')

FORM_CONFIG = {
  '21-2680' => {
    plain_name: 'Dependency Claim',
    full_name: 'Dependency Claim (VA Form 21-2680)',
    email_path: %w[claimant_contact claimant_email],
    name_path: %w[claimant_information claimant_full_name first]
  },
  '21P-8416' => {
    plain_name: 'Disability Benefits Questionnaire',
    full_name: 'Disability Benefits Questionnaire (VA Form 21P-8416)',
    email_path: %w[email],
    name_path: %w[claimant_full_name first]
  },
  '21P-534EZ' => {
    plain_name: "Survivor's Pension",
    full_name: "Survivor's Pension (VA Form 21P-534EZ)",
    email_path: %w[claimant_email],
    name_path: %w[claimant_full_name first]
  },
  '22-0839' => {
    plain_name: 'Yellow Ribbon Program',
    full_name: 'Yellow Ribbon Program (VA Form 22-0839)',
    email_path: %w[points_of_contact email],
    name_path: %w[authorized_official full_name first]
  },
  '22-10275' => {
    plain_name: 'Yellow Ribbon Program Application',
    full_name: 'Yellow Ribbon Program Application (VA Form 22-10275)',
    email_path: %w[points_of_contact email],
    name_path: %w[authorized_official full_name first]
  },
  '10-7959F-1' => {
    plain_name: 'Foreign Medical Program Registration',
    full_name: 'Foreign Medical Program Registration (VA Form 10-7959F-1)',
    email_path: %w[veteran_email_address],
    name_path: %w[veteran_full_name first]
  },
  '10-7959F-2' => {
    plain_name: 'Foreign Medical Program Registration',
    full_name: 'Foreign Medical Program Registration (VA Form 10-7959F-2)',
    email_path: %w[veteran_email_address],
    name_path: %w[veteran_full_name first]
  },
  '28-1900' => {
    plain_name: 'Vocational Rehabilitation and Employment',
    full_name: 'Vocational Rehabilitation and Employment (VA Form 28-1900)',
    email_path: %w[email],
    name_path: %w[full_name first]
  }
}.freeze

FORM_IDS = FORM_CONFIG.keys.freeze

namespace :va_notify do
  desc 'Notify users affected by the _is_valid bug in InProgressForm data'
  task notify_affected_form_users: :environment do
    affected_users = collect_affected_users
    puts "Found #{affected_users.count} users to notify"

    if affected_users.empty?
      puts 'No affected users found. Exiting.'
      next
    end

    enqueue_notifications(affected_users)
  end

  def collect_affected_users
    forms = InProgressForm.where(form_id: FORM_IDS).where(updated_at: 60.days.ago..Time.zone.parse('2026-02-26'))
                          .not_submitted

    affected_users = []

    forms.each do |form|
      data = JSON.parse(form.form_data)
      next unless data.to_json.include?('"_is_valid"')

      email, first_name = extract_contact_info(form.form_id, data)
      next if email.blank?

      affected_users << {
        form_id: form.id,
        form_type: form.form_id,
        email:,
        first_name:,
        updated_at: form.updated_at,
        metadata: FORM_CONFIG[form.form_id].slice(:plain_name, :full_name)
      }
    rescue => e
      puts "Error processing form #{form.id}: #{e.class}"
    end

    affected_users
  end

  def extract_contact_info(form_id, data)
    config = FORM_CONFIG[form_id]
    return [nil, nil] unless config

    [data.dig(*config[:email_path]), data.dig(*config[:name_path])]
  end

  def enqueue_notifications(affected_users, template_id:)
    batch    = Sidekiq::Batch.new
    throttle = Sidekiq::Limiter.concurrent('va_notify_affected_form_users', 15, wait_timeout: 5, lock_timeout: 30)

    batch.description = "_is_valid bug notification — #{affected_users.count} users — #{Time.current.iso8601}"

    batch.jobs do
      affected_users.each do |user|
        throttle.within_limit do
          VANotify::EmailJob.perform_async(
            user[:email],
            template_id,
            {
              'first_name' => user[:first_name].to_s,
              'form_full_name' => user[:metadata][:full_name],
              'form_plain_name' => user[:metadata][:plain_name],
              'updated_at' => user[:updated_at].strftime('%B %d, %Y')
            }
          )
        end
      end
    end

    puts "Batch #{batch.bid} created — #{affected_users.count} jobs enqueued"
  end
end
