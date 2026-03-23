# frozen_string_literal: true

FactoryBot.define do
  factory :supporting_document, class: 'ClaimsApi::SupportingDocument' do
    id { SecureRandom.uuid }
    auto_established_claim

    transient do
      custom_filename { 'custom_file_name.pdf' }
      doc_type { 'docType' }
      description { 'description' }
    end

    after(:build) do |supporting_document, evaluator|
      supporting_document.set_file_data!(
        Rack::Test::UploadedFile.new(
          Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
        ),
        evaluator.doc_type,
        evaluator.description
      )
      # Override the filename and computed hashes with custom values
      # due to bug with filename being wiped in test when Tempfile is created in the uploader
      supporting_document.file_data = {
        'filename' => evaluator.custom_filename,
        'doc_type' => evaluator.doc_type,
        'description' => evaluator.description
      }
    end
  end
end
