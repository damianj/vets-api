# frozen_string_literal: true

module Swagger
  module Requests
    class Cave
      include Swagger::Blocks

      swagger_schema :CaveIntakeRequest do
        key :required, %i[pdf_b64 file_name]

        property :pdf_b64,
                 type: :string,
                 description: 'Base64-encoded PDF contents to submit to the document processing pipeline',
                 example: 'JVBERi0xLjQKJcfs...'
        property :file_name,
                 type: :string,
                 description: 'Original filename forwarded to the upstream intake service',
                 example: 'test.pdf'
      end

      swagger_schema :CaveIntakeResponse do
        key :required, [:id]

        property :id, type: :string, example: 'abc123'
      end

      swagger_schema :CaveStatusResponse do
        key :required, [:scan_status]

        property :id, type: :string, example: 'abc123'
        property :scan_status, type: :string, enum: %w[pending completed failed], example: 'completed'
        property :error, type: :object do
          property :scan_status, type: :string, example: 'failed'
          property :step, type: :string, example: 'classification'
          property :error_type, type: :string, example: 'processing_error'
          property :error_message, type: :string, example: 'Unable to classify document'
        end
        property :warnings do
          key :type, :array
          items do
            key :type, :object
          end
        end
      end

      swagger_schema :CaveOutputResponse do
        key :description, 'Output extracted by the upstream document processor. Payload shape varies by document type.'

        property :forms do
          key :type, :array
          items do
            property :mmsFormValidationId, type: :string, example: 'form-kvp-123'
            property :mmsArtifactValidationId, type: :string, example: 'artifact-kvp-456'
          end
        end
      end

      swagger_schema :CaveKeyValuePayload do
        key :description, 'Arbitrary JSON object associated with a KVP identifier.'

        property :FIRST_NAME, type: :string, example: 'Ada'
        property :LAST_NAME, type: :string, example: 'Lovelace'
      end

      swagger_schema :CaveDiffRequest do
        key :required, %i[lhs rhs]

        property :lhs, type: :object, description: 'Original JSON object to compare'
        property :rhs, type: :object, description: 'Updated JSON object to compare'
      end

      swagger_schema :CaveDiffResponse do
        key :required, %i[is_different diff]

        property :is_different, type: :boolean, example: true
        property :diff do
          key :type, :array
          items do
            key :type, :object
            property :first_name, type: :object do
              property :lhs, type: :string, example: 'jee'
              property :rhs, type: :string, example: 'john'
              property :is_different, type: :boolean, example: true
            end
          end
        end
      end

      swagger_schema :CaveServiceUnavailable do
        key :required, [:errors]

        property :errors do
          key :type, :array
          items do
            key :$ref, :Error
          end
        end
      end

      swagger_path '/v0/cave' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::ForbiddenError

          key :description, 'Submit a PDF to the CAVE document processing proxy'
          key :operationId, 'createCaveDocument'
          key :tags, %w[cave]
          key :consumes, ['application/json']
          key :produces, ['application/json']

          parameter :authorization

          parameter do
            key :name, :document
            key :in, :body
            key :description, 'Document intake payload'
            key :required, true
            schema do
              key :$ref, :CaveIntakeRequest
            end
          end

          response 200 do
            key :description, 'Document accepted for processing'
            schema do
              key :$ref, :CaveIntakeResponse
            end
          end

          response 502 do
            key :description, 'Document processing service unavailable'
            schema do
              key :$ref, :CaveServiceUnavailable
            end
          end
        end
      end

      swagger_path '/v0/cave/{id}/status' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ForbiddenError

          key :description, 'Get the current processing status for a submitted document'
          key :operationId, 'getCaveDocumentStatus'
          key :tags, %w[cave]
          key :produces, ['application/json']

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'Document identifier returned by POST /v0/cave'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Current document status'
            schema do
              key :$ref, :CaveStatusResponse
            end
          end

          response 502 do
            key :description, 'Document processing service unavailable'
            schema do
              key :$ref, :CaveServiceUnavailable
            end
          end
        end
      end

      swagger_path '/v0/cave/{id}/output' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ForbiddenError

          key :description, 'Retrieve extracted document output for a processed document'
          key :operationId, 'getCaveDocumentOutput'
          key :tags, %w[cave]
          key :produces, ['application/json']

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'Document identifier returned by POST /v0/cave'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :type
            key :in, :query
            key :description, "Output variant to request. Defaults to 'artifact' when omitted."
            key :required, false
            key :type, :string
            key :enum, %w[artifact form]
          end

          response 200 do
            key :description, 'Extracted output payload'
            schema do
              key :$ref, :CaveOutputResponse
            end
          end

          response 502 do
            key :description, 'Document processing service unavailable'
            schema do
              key :$ref, :CaveServiceUnavailable
            end
          end
        end
      end

      swagger_path '/v0/cave/{id}/download' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::ForbiddenError

          key :description, 'Download the JSON payload for a specific extracted key-value pair'
          key :operationId, 'downloadCaveDocumentOutput'
          key :tags, %w[cave]
          key :produces, ['application/json']

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'Document identifier returned by POST /v0/cave'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :kvpid
            key :in, :query
            key :description, 'Key-value pair identifier from a prior output response'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Stored JSON payload for the requested KVP record'
            schema do
              key :$ref, :CaveKeyValuePayload
            end
          end

          response 502 do
            key :description, 'Document processing service unavailable'
            schema do
              key :$ref, :CaveServiceUnavailable
            end
          end
        end
      end

      swagger_path '/v0/cave/{id}/update' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::ForbiddenError

          key :description, 'Replace the JSON payload for a specific extracted key-value pair'
          key :operationId, 'updateCaveDocumentOutput'
          key :tags, %w[cave]
          key :consumes, ['application/json']
          key :produces, ['application/json']

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'Document identifier returned by POST /v0/cave'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :kvpid
            key :in, :query
            key :description, 'Key-value pair identifier from a prior output response'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :payload
            key :in, :body
            key :description, 'Replacement JSON object for the selected KVP record'
            key :required, true
            schema do
              key :$ref, :CaveKeyValuePayload
            end
          end

          response 200 do
            key :description, 'Updated JSON payload'
            schema do
              key :$ref, :CaveKeyValuePayload
            end
          end

          response 502 do
            key :description, 'Document processing service unavailable'
            schema do
              key :$ref, :CaveServiceUnavailable
            end
          end
        end
      end

      swagger_path '/v0/cave/diff' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadRequestError

          key :description, 'Compare two JSON objects and return the detected field-level differences'
          key :operationId, 'diffCavePayloads'
          key :tags, %w[cave]
          key :consumes, ['application/json']
          key :produces, ['application/json']

          parameter :authorization

          parameter do
            key :name, :payload
            key :in, :body
            key :description, "JSON object containing both 'lhs' and 'rhs' payloads"
            key :required, true
            schema do
              key :$ref, :CaveDiffRequest
            end
          end

          response 200 do
            key :description, 'Computed differences between the provided payloads'
            schema do
              key :$ref, :CaveDiffResponse
            end
          end
        end
      end
    end
  end
end
