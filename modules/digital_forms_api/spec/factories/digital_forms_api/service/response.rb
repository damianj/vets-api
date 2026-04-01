# frozen_string_literal: true

FactoryBot.define do
  factory :digital_forms_service_response, class: 'OpenStruct' do
    trait :success do
      reason_phrase { 'OK' }
      status { 200 }
      body do
        JSON.parse('{
          "submission": {
            "submissionId": "a1ba50e4-e689-4852-bec7-2a66519f0ed3",
            "claimId": "123456789"
          }
        }')
      end
    end
  end

  factory :digital_forms_service_error, class: 'Common::Client::Errors::ClientError' do
    trait :error do
      status { 503 }
      message { 'VEFSERR40009' }
      body do
        JSON.parse('{
          "message": "Service unavailable."
        }')
      end

      initialize_with { new(message, status, body) }
    end

    trait :single do
      status { 418 }
      message { 'VEFSERR40009' }
      body do
        JSON.parse('{
          "messages": [
            {
              "timestamp": "2024-05-20T15:53:29.389",
              "key": "bip.framework.service.teapot",
              "severity": "ERROR",
              "status": "418",
              "text": "I am a teapot."
            }
          ]
        }')
      end

      initialize_with { new(message, status, body) }
    end

    trait :multiple do
      status { 403 }
      message { 'VEFSERR40009' }
      body do
        JSON.parse('{
          "messages": [
            {
              "key": "bip.framework.not.authorized.exception",
              "severity": "ERROR",
              "status": 403,
              "text": "Access denied.",
              "timestamp": "2019-08-29T18:40:22.766Z"
            },
            {
              "timestamp": "2024-05-20T15:53:29.389",
              "key": "bip.framework.service.teapot",
              "severity": "ERROR",
              "status": "418",
              "text": "I am a teapot."
            }
          ]
        }')
      end

      initialize_with { new(message, status, body) }
    end
  end
end
