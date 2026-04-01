# frozen_string_literal: true

require 'rails_helper'
require 'rake'

unless defined?(Sidekiq::Batch)
  module Sidekiq
    class Batch
      def bid; end
      def description=(_); end
      def jobs = yield
    end
  end
end

unless defined?(Sidekiq::Limiter)
  module Sidekiq
    module Limiter
      class Concurrent
        def within_limit = yield
      end

      def self.concurrent(*); end
    end
  end
end

RSpec.describe 'va_notify:notify_affected_form_users', type: :task do
  let(:task) { Rake::Task['va_notify:notify_affected_form_users'] }

  before do
    Rake::Task.clear
    load File.expand_path('../../lib/tasks/notify_affected_form_users.rake', __dir__)
    Rake::Task.define_task(:environment)
  end

  after { task.reenable }

  def form_data_for(form_id, with_is_valid: true)
    base = case form_id
           when '21-2680'
             {
               'claimant_contact' => { 'claimant_email' => 'veteran@example.com' },
               'claimant_information' => { 'claimant_full_name' => { 'first' => 'John' } }
             }
           when '21P-8416'
             { 'email' => 'veteran@example.com', 'claimant_full_name' => { 'first' => 'John' } }
           when '21P-534EZ'
             { 'claimant_email' => 'veteran@example.com', 'claimant_full_name' => { 'first' => 'John' } }
           when '22-0839', '22-10275'
             { 'points_of_contact' => { 'email' => 'veteran@example.com' },
               'authorized_official' => { 'full_name' => { 'first' => 'John' } } }
           when '10-7959F-1', '10-7959F-2'
             { 'veteran_email_address' => 'veteran@example.com', 'veteran_full_name' => { 'first' => 'John' } }
           when '28-1900'
             { 'email' => 'veteran@example.com', 'full_name' => { 'first' => 'John' } }
           end

    base.merge!('_is_valid' => true) if with_is_valid
    base
  end

  def create_form(form_id:, updated_at: 30.days.ago, form_data: nil)
    create(:in_progress_form,
           form_id:,
           updated_at:,
           form_data: form_data || form_data_for(form_id))
  end

  def stub_batch_and_throttle
    batch    = double('Sidekiq::Batch', bid: 'test-bid-123')
    throttle = instance_double(Sidekiq::Limiter::Concurrent)

    allow(Sidekiq::Batch).to receive(:new).and_return(batch)
    allow(Sidekiq::Limiter).to receive(:concurrent).and_return(throttle)
    allow(batch).to receive(:'description=')
    allow(batch).to receive(:jobs).and_yield
    allow(throttle).to receive(:within_limit).and_yield

    [batch, throttle]
  end

  describe 'collect_affected_users' do
    it 'includes forms with _is_valid in form_data' do
      create_form(form_id: '21-2680', updated_at: Time.zone.parse('2026-01-15'))
      expect(collect_affected_users.count).to eq(1)
    end

    it 'excludes forms without _is_valid in form_data' do
      create_form(form_id: '21-2680', form_data: form_data_for('21-2680', with_is_valid: false))
      expect(collect_affected_users).to be_empty
    end

    it 'excludes forms with a blank email' do
      create_form(form_id: '21-2680', updated_at: Time.zone.parse('2026-01-15'),
                  form_data: { '_is_valid' => true, 'claimant_contact' => { 'claimant_email' => '' } })
      expect(collect_affected_users).to be_empty
    end

    it 'excludes forms outside the date range' do
      create_form(form_id: '21-2680', updated_at: Time.zone.parse('2025-11-30'))
      create_form(form_id: '21-2680', updated_at: Time.zone.parse('2026-02-27'))
      expect(collect_affected_users).to be_empty
    end

    it 'skips forms that raise errors without raising' do
      create_form(form_id: '21-2680', updated_at: Time.zone.parse('2026-01-15'))
      allow_any_instance_of(InProgressForm).to receive(:form_data).and_raise(StandardError)
      expect { collect_affected_users }.not_to raise_error
    end
  end

  describe 'extract_contact_info' do
    {
      '21-2680' => {
        data: { 'claimant_contact' => { 'claimant_email' => 'test@example.com' },
                'claimant_information' => { 'claimant_full_name' => { 'first' => 'Jane' } } },
        expected_email: 'test@example.com', expected_name: 'Jane'
      },
      '21P-8416' => {
        data: { 'email' => 'test@example.com', 'claimant_full_name' => { 'first' => 'Jane' } },
        expected_email: 'test@example.com', expected_name: 'Jane'
      },
      '21P-534EZ' => {
        data: { 'claimant_email' => 'test@example.com', 'claimant_full_name' => { 'first' => 'Jane' } },
        expected_email: 'test@example.com', expected_name: 'Jane'
      },
      '22-0839' => {
        data: { 'points_of_contact' => { 'email' => 'test@example.com' },
                'authorized_official' => { 'full_name' => { 'first' => 'Jane' } } },
        expected_email: 'test@example.com', expected_name: 'Jane'
      },
      '10-7959F-1' => {
        data: { 'veteran_email_address' => 'test@example.com', 'veteran_full_name' => { 'first' => 'Jane' } },
        expected_email: 'test@example.com', expected_name: 'Jane'
      },
      '28-1900' => {
        data: { 'email' => 'test@example.com', 'full_name' => { 'first' => 'Jane' } },
        expected_email: 'test@example.com', expected_name: 'Jane'
      }
    }.each do |form_id, config|
      it "extracts email and first_name for #{form_id}" do
        email, first_name = extract_contact_info(form_id, config[:data])
        expect(email).to eq(config[:expected_email])
        expect(first_name).to eq(config[:expected_name])
      end
    end

    it 'returns [nil, nil] for an unknown form_id' do
      expect(extract_contact_info('99-9999', {})).to eq([nil, nil])
    end
  end

  describe 'enqueue_notifications' do
    let(:user) do
      {
        form_id: 1,
        form_type: '21-2680',
        email: 'veteran@example.com',
        first_name: 'John',
        updated_at: 30.days.ago,
        metadata: { full_name: 'Dependency Claim (VA Form 21-2680)', plain_name: 'Dependency Claim' }
      }
    end
    let(:user_without_first_name) { user.merge(first_name: nil) }

    before do
      stub_batch_and_throttle
    end

    it 'throttles to 15 concurrent jobs' do
      allow(VANotify::EmailJob).to receive(:perform_async)
      expect(Sidekiq::Limiter).to receive(:concurrent).with(
        'va_notify_affected_form_users',
        15,
        hash_including(:wait_timeout, :lock_timeout)
      )
      enqueue_notifications([user], template_id: 'test-template-id')
    end

    it 'enqueues a job with the correct template id and personalisation' do
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        'veteran@example.com',
        'test-template-id',
        {
          'first_name' => 'John',
          'form_full_name' => 'Dependency Claim (VA Form 21-2680)',
          'form_plain_name' => 'Dependency Claim',
          'updated_at' => user[:updated_at].strftime('%B %d, %Y')
        },
        anything,
        anything
      )
      enqueue_notifications([user], template_id: 'test-template-id')
    end

    it 'falls back to empty string when first_name is nil' do
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        anything, anything, hash_including('first_name' => ''), anything, anything
      )
      enqueue_notifications([user_without_first_name], template_id: 'test-template-id')
    end

    it 'includes callback_metadata with in_progress_form_id, form_number, and function' do
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        anything,
        anything,
        anything,
        anything,
        {
          callback_metadata: {
            notification_type: 'other',
            in_progress_form_id: user[:form_id],
            form_number: user[:form_type],
            statsd_tags: {
              'service' => 'veteran-facing-forms',
              'function' => '_is_valid bug notification'
            }
          }
        }
      )
      enqueue_notifications([user], template_id: 'test-template-id')
    end
  end
end
