# frozen_string_literal: true

module RetriableConcern
  extend ActiveSupport::Concern

  TRANSIENT_ERRORS = [
    Timeout::Error,
    Errno::ECONNRESET,
    Net::OpenTimeout,
    PG::ConnectionBad,
    PG::QueryCanceled,
    PG::TRSerializationFailure,
    ActiveRecord::ConnectionNotEstablished
  ].freeze

  def with_retries(block_name, tries: 3, base_interval: 1, on: TRANSIENT_ERRORS)
    block_name = block_name.to_s
    attempt = 0

    begin
      attempt += 1
      yield
    rescue *on => e
      if attempt < tries
        Rails.logger.warn("Retrying #{block_name} (Attempt #{attempt}/#{tries}): #{e.class}")
        sleep(backoff_interval(base_interval, attempt))
        retry
      end
      Rails.logger.error("#{block_name} failed after max retries", { error: e.message, backtrace: e.backtrace })
      raise
    end
  end

  private

  def backoff_interval(base_interval, attempt, jitter: rand)
    base_interval * (2**(attempt - 1)) * (1 + (jitter * 0.1))
  end
end
