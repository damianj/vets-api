# frozen_string_literal: true

require 'digital_forms_api/service/base'

module DigitalFormsApi
  module Service
    # Templates API
    class Templates < Base
      # Cache TTL values for form templates
      CACHE_TTL = (Settings.digital_forms_api.cache_ttl.template.to_i || 5).minutes

      # Build the cache key for a given form template.
      def self.cache_key(form_id)
        "digital_forms_api:template:#{form_id}"
      end

      # @see #template
      def self.get(form_id)
        new.template(form_id)
      end

      # GET a form template (with caching)
      # Caches only the parsed response body to avoid persisting sensitive
      # request metadata (e.g., Authorization headers) from the Faraday::Env.
      def template(form_id)
        cache_key = self.class.cache_key(form_id)

        # @see DigitalFormsApi::Service::Base#context
        tags = { form_id: }
        @context = tags.merge(tags:)

        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL, race_condition_ttl: 10.seconds) do
          perform(:get, "forms/#{form_id}/template", {}, {}).body
        end
      end

      private

      # @see DigitalFormsApi::Service::Base#endpoint
      def endpoint
        'templates'
      end

      # end Templates
    end

    # end Service
  end

  # end DigitalFormsApi
end
