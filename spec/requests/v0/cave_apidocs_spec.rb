# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CAVE API docs', type: :request do
  subject(:apidocs) { JSON.parse(response.body) }

  before { get '/v0/apidocs.json' }

  it 'documents the cave tag and all cave routes' do
    expect(response).to have_http_status(:ok)
    expect(apidocs['tags']).to include(hash_including('name' => 'cave'))

    expect(apidocs['paths']).to include(
      '/v0/cave',
      '/v0/cave/{id}/status',
      '/v0/cave/{id}/output',
      '/v0/cave/{id}/download',
      '/v0/cave/{id}/update',
      '/v0/cave/diff'
    )

    expect(apidocs.dig('paths', '/v0/cave', 'post', 'operationId')).to eq('createCaveDocument')
    expect(apidocs.dig('paths', '/v0/cave/{id}/status', 'get', 'operationId')).to eq('getCaveDocumentStatus')
    expect(apidocs.dig('paths', '/v0/cave/{id}/output', 'get', 'operationId')).to eq('getCaveDocumentOutput')
    expect(apidocs.dig('paths', '/v0/cave/{id}/download', 'get', 'operationId')).to eq('downloadCaveDocumentOutput')
    expect(apidocs.dig('paths', '/v0/cave/{id}/update', 'post', 'operationId')).to eq('updateCaveDocumentOutput')
    expect(apidocs.dig('paths', '/v0/cave/diff', 'post', 'operationId')).to eq('diffCavePayloads')
  end

  it 'includes the cave request and response schemas' do
    expect(apidocs['definitions']).to include(
      'CaveIntakeRequest',
      'CaveIntakeResponse',
      'CaveStatusResponse',
      'CaveOutputResponse',
      'CaveKeyValuePayload',
      'CaveDiffRequest',
      'CaveDiffResponse',
      'CaveServiceUnavailable'
    )

    expect(apidocs.dig('paths', '/v0/cave', 'post', 'parameters')).to include(
      hash_including('name' => 'document', 'schema' => { '$ref' => '#/definitions/CaveIntakeRequest' })
    )
    expect(apidocs.dig('paths', '/v0/cave', 'post', 'responses', '200', 'schema'))
      .to eq('$ref' => '#/definitions/CaveIntakeResponse')
    expect(apidocs.dig('paths', '/v0/cave/{id}/update', 'post', 'parameters')).to include(
      hash_including('name' => 'payload', 'schema' => { '$ref' => '#/definitions/CaveKeyValuePayload' })
    )
    expect(apidocs.dig('paths', '/v0/cave/diff', 'post', 'responses', '200', 'schema'))
      .to eq('$ref' => '#/definitions/CaveDiffResponse')
  end
end
