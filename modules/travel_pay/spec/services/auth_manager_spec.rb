# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::AuthManager do
  context 'get_tokens' do
    let(:user_account) { create(:user_account) }
    let(:user_verification) { create(:user_verification, user_account:) }
    let(:idme_uuid) { user_verification.idme_uuid }
    let!(:user) { create(:user, :loa3, user_account:, user_verification:, idme_uuid:) }
    let(:auth_session) do
      TravelPay::AuthSession.new(
        veis_token: 'fake_veis_token',
        btsss_token: 'fake_btsss_token'
      )
    end
    let(:expected_veis_token) { 'fake_veis_token' }
    let(:expected_btsss_token) { 'fake_btsss_token' }
    let(:cached_tokens) do
      {
        user_account_id: user.user_account_uuid,
        veis_token: 'cached_veis_token',
        btsss_token: 'cached_btsss_token'
      }
    end
    let(:tokens_response) do
      Faraday::Response.new(
        body: tokens
      )
    end

    context 'authorize' do
      it 'returns an AuthSession with a veis_token and a btsss_token and stores it in the cache' do
        client_number = 123

        allow_any_instance_of(TravelPay::TokenClient)
          .to receive(:authorized_user_session)
          .with(user)
          .and_return(auth_session)

        service = TravelPay::AuthManager.new(client_number, user)
        response = service.authorize
        expect(response).to be_a(TravelPay::AuthSession)
        expect(response.veis_token).to eq(expected_veis_token)
        expect(response.btsss_token).to eq(expected_btsss_token)
        # Verify that the tokens were stored
        expect($redis.ttl("travel-pay-store:#{user.user_account_uuid}")).to eq(3300)
        saved_tokens = $redis.get("travel-pay-store:#{user.user_account_uuid}")
        Oj.load(saved_tokens) => { veis_token:, btsss_token: }
        expect(veis_token).to eq(expected_veis_token)
        expect(btsss_token).to eq(expected_btsss_token)
      end
    end

    context 'uses cached tokens' do
      before do
        $redis.set("travel-pay-store:#{user.user_account_uuid}", Oj.dump(cached_tokens))
      end

      it 'returns a cached veis_token and btsss_token' do
        client_number = 123
        service = TravelPay::AuthManager.new(client_number, user)
        response = service.authorize
        expect(response).to be_a(TravelPay::AuthSession)
        expect(response.veis_token).to eq('cached_veis_token')
        expect(response.btsss_token).to eq('cached_btsss_token')
      end
    end
  end
end
