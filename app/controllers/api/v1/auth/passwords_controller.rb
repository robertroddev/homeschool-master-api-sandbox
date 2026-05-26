# frozen_string_literal: true

module Api
  module V1
    module Auth
      class PasswordsController < BaseController
        # reset_request and reset are part of the forgot-password flow and must be
        # reachable without a session. change requires an authenticated teacher.
        skip_before_action :authenticate_request, only: %i[reset_request reset]

        # POST /api/v1/auth/password/reset-request
        def reset_request
          PasswordResetService.request_reset(params[:email])

          # Always OK, whether or not the email exists (no account enumeration).
          render_success(
            { message: 'If an account exists for that email, a password reset link is on its way.' }
          )
        end

        # POST /api/v1/auth/password/reset
        def reset
          result = PasswordResetService.reset(params[:token], params[:password])

          if result[:success]
            render_success({ message: 'Your password has been reset. You can now log in.' })
          elsif result[:validation_errors]
            render_validation_errors(result[:validation_errors])
          else
            render_error(result[:error], code: 'INVALID_RESET_TOKEN', status: :unprocessable_entity)
          end
        end

        # POST /api/v1/auth/password/change (authenticated)
        def change
          unless current_teacher.authenticate(params[:current_password])
            return render_unauthorized('Current password is incorrect')
          end

          current_teacher.password = params[:password]

          if current_teacher.save
            render_success({ message: 'Your password has been updated.' })
          else
            render_validation_errors(current_teacher)
          end
        end
      end
    end
  end
end
