# frozen_string_literal: true

require 'digital_forms_api/service/base'

module DigitalFormsApi
  module Service
    # Schemas API
    class Schemas < Base
      # Cache TTL values for form schemas
      CACHE_TTL = (Settings.digital_forms_api.cache_ttl.schema.to_i || 5).minutes

      # Build the cache key for a given form template.
      def self.cache_key(form_id)
        "digital_forms_api:schema:#{form_id}"
      end

      # @see #schema
      def self.get(form_id)
        new.schema(form_id)
      end

      # GET a form schema (with caching)
      # Caches only the parsed response body to avoid persisting sensitive
      # request metadata (e.g., Authorization headers) from the Faraday::Env.
      def schema(form_id)
        cache_key = self.class.cache_key(form_id)

        # @see DigitalFormsApi::Service::Base#context
        tags = { form_id: }
        @context = tags.merge(tags:)

        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL, race_condition_ttl: 10.seconds) do
          perform(:get, "forms/#{form_id}/schema", {}, {}).body
        end
      end

      private

      # @see DigitalFormsApi::Service::Base#endpoint
      def endpoint
        'schemas'
      end

      # end Schemas
    end

    # end Service
  end

  # end DigitalFormsApi
end
