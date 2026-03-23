# frozen_string_literal: true

require_relative 'concerns/claim_base'
require_relative 'concerns/contention_list'
require_relative 'concerns/events_timeline'
require_relative 'concerns/va_representative'

module ClaimsApi
  class ClaimDetailSerializer
    include JSONAPI::Serializer
    include Concerns::ClaimBase
    include Concerns::ContentionList
    include Concerns::EventsTimeline
    include Concerns::VARepresentative

    set_type :claims_api_claim

    set_id do |object, params|
      params[:uuid] || object&.evss_id
    end

    attribute :status do |object|
      phase = phase_from_keys(object, 'claim_phase_dates', 'latest_phase_type')
      object.status_from_phase(phase)
    end

    # evss_claim.rb has supporting_documents serialized already
    # but auto_established_claim.rb does not, so fallback handles both cases
    attribute :supporting_documents do |object|
      object.supporting_documents.map do |document|
        {
          id: document[:id] || document.id,
          type: 'claim_supporting_document',
          md5: document[:md5] || (
            document.file_data&.dig('filename').present? ? Digest::MD5.hexdigest(document.file_data['filename']) : ''
          ),
          header_hash: document[:header_hash] || (
            document.file_data&.dig('filename').present? ? Digest::SHA256.hexdigest(document.file_data['filename']) : ''
          ),
          filename: document[:filename] || document&.file_data&.dig('filename'),
          uploaded_at: document[:uploaded_at] || document.created_at
        }
      end
    end

    def self.object_data(object)
      object.data
    end
  end
end
