# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth::Passwords', type: :request do
  context 'POST /api/v1/auth/password/reset-request' do
    describe 'when the email belongs to an existing account' do
      before do
        @teacher = FactoryBot.create(:teacher)
      end

      it 'returns a successful response' do
        post api_v1_auth_password_reset_request_url, params: { email: @teacher.email }
        expect(response).to have_http_status(:ok)
      end

      it 'sets a password reset token on the teacher' do
        post api_v1_auth_password_reset_request_url, params: { email: @teacher.email }
        expect(@teacher.reload.password_reset_token).to be_present
        expect(@teacher.password_reset_sent_at).to be_present
      end

      it 'enqueues the reset email' do
        expect do
          post api_v1_auth_password_reset_request_url, params: { email: @teacher.email }
        end.to have_enqueued_mail(PasswordResetMailer, :reset_email)
      end

      it 'finds the account regardless of email casing' do
        post api_v1_auth_password_reset_request_url, params: { email: @teacher.email.upcase }
        expect(@teacher.reload.password_reset_token).to be_present
      end
    end

    describe 'when the email does not belong to any account' do
      it 'still returns a successful response (no account enumeration)' do
        post api_v1_auth_password_reset_request_url, params: { email: 'nobody@example.com' }
        expect(response).to have_http_status(:ok)
      end

      it 'does not enqueue any email' do
        expect do
          post api_v1_auth_password_reset_request_url, params: { email: 'nobody@example.com' }
        end.not_to have_enqueued_mail(PasswordResetMailer, :reset_email)
      end

      it 'logs a warning that the email did not exist and no link was sent' do
        expect(Rails.logger).to receive(:warn).with(/non-existent email: nobody@example.com/)
        post api_v1_auth_password_reset_request_url, params: { email: 'nobody@example.com' }
      end
    end
  end

  context 'POST /api/v1/auth/password/reset' do
    before do
      @teacher = FactoryBot.create(:teacher)
      @teacher.generate_password_reset_token!
      @token = @teacher.password_reset_token
    end

    describe 'when the token is valid' do
      it 'returns a successful response' do
        post api_v1_auth_password_reset_url, params: { token: @token, password: 'newpassword123' }
        expect(response).to have_http_status(:ok)
      end

      it 'updates the password' do
        post api_v1_auth_password_reset_url, params: { token: @token, password: 'newpassword123' }
        expect(@teacher.reload.authenticate('newpassword123')).to be_truthy
      end

      it 'clears the reset token so it cannot be reused' do
        post api_v1_auth_password_reset_url, params: { token: @token, password: 'newpassword123' }
        expect(@teacher.reload.password_reset_token).to be_nil
      end
    end

    describe 'when the token has expired' do
      before do
        @teacher.update!(password_reset_sent_at: 2.hours.ago)
      end

      it 'returns an unprocessable response' do
        post api_v1_auth_password_reset_url, params: { token: @token, password: 'newpassword123' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not change the password' do
        post api_v1_auth_password_reset_url, params: { token: @token, password: 'newpassword123' }
        expect(@teacher.reload.authenticate('newpassword123')).to be_falsey
      end
    end

    describe 'when the token is invalid' do
      it 'returns an unprocessable response for a wrong token' do
        post api_v1_auth_password_reset_url, params: { token: 'not-a-real-token', password: 'newpassword123' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns an unprocessable response for a blank token' do
        post api_v1_auth_password_reset_url, params: { token: '', password: 'newpassword123' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not match an account that happens to have a nil token' do
        # Guards against find_by(password_reset_token: nil) matching real users.
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        post api_v1_auth_password_reset_url, params: { token: '', password: 'newpassword123' }
        expect(other.reload.authenticate('newpassword123')).to be_falsey
      end
    end

    describe 'when the new password is too short' do
      it 'returns a validation error' do
        post api_v1_auth_password_reset_url, params: { token: @token, password: 'short' }
        json_response = JSON.parse(response.body)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['details']['password']).to be_present
      end
    end
  end

  context 'POST /api/v1/auth/password/change' do
    describe 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
      end

      it 'changes the password with the correct current password' do
        post api_v1_auth_password_change_url,
             params: { current_password: 'password123', password: 'brandnew123' }
        expect(response).to have_http_status(:ok)
        expect(@teacher.reload.authenticate('brandnew123')).to be_truthy
      end

      it 'rejects an incorrect current password' do
        post api_v1_auth_password_change_url,
             params: { current_password: 'wrongpassword', password: 'brandnew123' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects a new password that is too short' do
        post api_v1_auth_password_change_url,
             params: { current_password: 'password123', password: 'short' }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'when not authenticated' do
      it 'returns an unauthorized response' do
        post api_v1_auth_password_change_url,
             params: { current_password: 'password123', password: 'brandnew123' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
