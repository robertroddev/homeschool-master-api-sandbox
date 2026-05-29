# frozen_string_literal: true

module Api
  module V1
    module Auth
      class EmailChangeController < BaseController
        # confirm is the link clicked from an email and runs without a session.
        skip_before_action :authenticate_request, only: %i[confirm]

        # POST /api/v1/auth/email/change (authenticated)
        def request_change
          unless current_teacher.authenticate(params[:current_password])
            return render_unauthorized('Current password is incorrect')
          end

          result = EmailChangeService.request_change(current_teacher, params[:email])

          if result[:success]
            render_success({ message: 'We sent a verification link to your new email address.' })
          else
            render_error(result[:error], code: 'EMAIL_CHANGE_ERROR', status: :unprocessable_entity)
          end
        end

        # POST /api/v1/auth/email/change/confirm (token-based, unauthenticated)
        def confirm
          result = EmailChangeService.confirm(params[:token])

          if result[:success]
            render_success({ message: 'Your email has been updated. Sign in with your new email.' })
          elsif result[:validation_errors]
            render_validation_errors(result[:validation_errors])
          else
            render_error(result[:error], code: 'INVALID_EMAIL_CHANGE_TOKEN', status: :unprocessable_entity)
          end
        end
      end
    end
  end
end
