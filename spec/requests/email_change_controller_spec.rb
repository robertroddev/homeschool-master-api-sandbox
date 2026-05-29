# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth::EmailChange', type: :request do
  context 'POST /api/v1/auth/email/change' do
    describe 'when authenticated with the correct password' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
      end

      it 'returns success' do
        post api_v1_auth_email_change_url,
             params: { email: 'new@example.com', current_password: 'password123' }
        expect(response).to have_http_status(:ok)
      end

      it 'sets a pending email and token on the teacher' do
        post api_v1_auth_email_change_url,
             params: { email: 'new@example.com', current_password: 'password123' }
        @teacher.reload
        expect(@teacher.pending_email).to eq('new@example.com')
        expect(@teacher.email_change_token).to be_present
        expect(@teacher.email_change_sent_at).to be_present
      end

      it 'does not change the current email yet' do
        original = @teacher.email
        post api_v1_auth_email_change_url,
             params: { email: 'new@example.com', current_password: 'password123' }
        expect(@teacher.reload.email).to eq(original)
      end

      it 'enqueues the confirmation email' do
        expect do
          post api_v1_auth_email_change_url,
               params: { email: 'new@example.com', current_password: 'password123' }
        end.to have_enqueued_mail(EmailChangeMailer, :change_request_email)
      end

      it 'rejects an email already in use by another teacher' do
        FactoryBot.create(:teacher, email: 'taken@example.com')
        post api_v1_auth_email_change_url,
             params: { email: 'taken@example.com', current_password: 'password123' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects the current email' do
        post api_v1_auth_email_change_url,
             params: { email: @teacher.email, current_password: 'password123' }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'when the current password is wrong' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
      end

      it 'returns unauthorized' do
        post api_v1_auth_email_change_url,
             params: { email: 'new@example.com', current_password: 'wrong' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not set a pending email' do
        post api_v1_auth_email_change_url,
             params: { email: 'new@example.com', current_password: 'wrong' }
        expect(@teacher.reload.pending_email).to be_nil
      end
    end

    describe 'when not authenticated' do
      it 'returns unauthorized' do
        post api_v1_auth_email_change_url,
             params: { email: 'new@example.com', current_password: 'password123' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  context 'POST /api/v1/auth/email/change/confirm' do
    describe 'with a valid token' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @teacher.generate_email_change_token!('new@example.com')
        @token = @teacher.email_change_token
      end

      it 'returns success' do
        post api_v1_auth_email_change_confirm_url, params: { token: @token }
        expect(response).to have_http_status(:ok)
      end

      it 'updates the email to the pending email' do
        post api_v1_auth_email_change_confirm_url, params: { token: @token }
        expect(@teacher.reload.email).to eq('new@example.com')
      end

      it 'marks the email as verified' do
        post api_v1_auth_email_change_confirm_url, params: { token: @token }
        expect(@teacher.reload.email_verified_at).to be_present
      end

      it 'clears the pending email and token' do
        post api_v1_auth_email_change_confirm_url, params: { token: @token }
        @teacher.reload
        expect(@teacher.pending_email).to be_nil
        expect(@teacher.email_change_token).to be_nil
        expect(@teacher.email_change_sent_at).to be_nil
      end
    end

    describe 'with an invalid token' do
      it 'returns an error' do
        post api_v1_auth_email_change_confirm_url, params: { token: 'bogus' }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'with an expired token' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @teacher.generate_email_change_token!('new@example.com')
        @teacher.update_column(:email_change_sent_at, 2.hours.ago)
        @token = @teacher.email_change_token
      end

      it 'returns an error' do
        post api_v1_auth_email_change_confirm_url, params: { token: @token }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not change the email' do
        original = @teacher.email
        post api_v1_auth_email_change_confirm_url, params: { token: @token }
        expect(@teacher.reload.email).to eq(original)
      end
    end

    describe 'when the pending email has been taken by another teacher' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @teacher.generate_email_change_token!('new@example.com')
        @token = @teacher.email_change_token
        FactoryBot.create(:teacher, email: 'new@example.com')
      end

      it 'returns an error' do
        post api_v1_auth_email_change_confirm_url, params: { token: @token }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not change the email' do
        original = @teacher.email
        post api_v1_auth_email_change_confirm_url, params: { token: @token }
        expect(@teacher.reload.email).to eq(original)
      end

      it 'clears the pending change so the user can retry' do
        post api_v1_auth_email_change_confirm_url, params: { token: @token }
        @teacher.reload
        expect(@teacher.pending_email).to be_nil
        expect(@teacher.email_change_token).to be_nil
      end
    end
  end
end
