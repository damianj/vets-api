# frozen_string_literal: true

module SimpleFormsApi
  module FormRemediation
    # Sidekiq job that retries failed S3 uploads for form remediation files.
    #
    # Enqueued by {SimpleFormsApi::FormRemediation::Uploader#store!} when an
    # +Aws::S3::Errors::ServiceError+ occurs during the initial upload attempt.
    #
    # @example Enqueue a retry (typically called from Uploader, not directly)
    #   UploadRetryJob.perform_async(file, directory, config)
    #
    # @see SimpleFormsApi::FormRemediation::Uploader
    class UploadRetryJob
      include Sidekiq::Job

      sidekiq_options retry: 10

      STATSD_KEY_PREFIX = 'api.simple_forms_api.upload_retry_job'

      sidekiq_retries_exhausted do |_msg, ex|
        StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted")
        Rails.logger.error(
          'SimpleFormsApi::FormRemediation::UploadRetryJob retries exhausted',
          { exception: "#{ex.class} - #{ex.message}", backtrace: ex.backtrace&.join("\n").to_s }
        )
      end

      # Attempts to upload a file to S3 via the configured uploader.
      #
      # Handles both direct invocation (with objects) and Sidekiq's +perform_async+
      # (where arguments are JSON-serialized into strings/hashes). Each argument is
      # normalized to the expected type before use.
      #
      # @param file [String, Hash, CarrierWave::SanitizedFile] file path, serialized hash, or file object
      # @param directory [String] the S3 target directory
      # @param config [String, Configuration::Base] config class name or config instance
      def perform(file, directory, config)
        @file = file.respond_to?(:filename) ? file : CarrierWave::SanitizedFile.new(file)
        @directory = directory
        @config = config.respond_to?(:uploader_class) ? config : config.to_s.constantize.new

        verify_file_exists!(@file)

        uploader = @config.uploader_class.new(directory:, config: @config)

        begin
          StatsD.increment("#{STATSD_KEY_PREFIX}.total")

          uploader.store!(@file)
        rescue Aws::S3::Errors::ServiceError
          raise if service_available?(@config.s3_settings.region)

          retry_later
        end
      end

      private

      attr_accessor :file, :directory, :config

      # Raises if the file no longer exists on disk. Callers typically delete
      # the source file after the initial upload attempt, so retries may arrive
      # with a stale path. Failing fast avoids burning Sidekiq retries.
      def verify_file_exists!(sanitized_file)
        path = sanitized_file.respond_to?(:path) ? sanitized_file.path : sanitized_file.to_s
        return if path.blank? || File.exist?(path)

        StatsD.increment("#{STATSD_KEY_PREFIX}.file_missing")
        raise "Retry file no longer exists at #{path}. Source was likely cleaned up after the initial upload failure."
      end

      # Checks whether the S3 service is reachable in the given region.
      #
      # @param region [String] AWS region (e.g. "us-gov-west-1")
      # @return [Boolean]
      def service_available?(region)
        Aws::S3::Client.new(region:).list_buckets
        true
      rescue Aws::S3::Errors::ServiceError
        false
      end

      # Re-enqueues this job with a delay when S3 is completely unavailable.
      # This avoids burning a Sidekiq retry on a known-down service.
      #
      # @param delay [Time] when to run the retry (default: 30 minutes from now)
      def retry_later(delay: 30.minutes.from_now)
        Rails.logger.info("S3 service unavailable. Retrying upload later for #{file.filename}.")
        self.class.perform_in(delay, file.path, directory, config.class.name)
      end
    end
  end
end
