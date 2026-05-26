# frozen_string_literal: true

class PasswordResetMailer < ApplicationMailer
  # Builds the password reset email. The link points at the WEB APP (not the API),
  # since the user lands on the frontend /reset-password page to set a new password.
  def reset_email(teacher)
    @teacher = teacher
    @reset_url = "#{web_app_url}/reset-password?token=#{teacher.password_reset_token}"

    mail(
      to: teacher.email,
      subject: 'Reset your Homeschool Master password'
    )
  end

  private

  def web_app_url
    ENV.fetch('WEB_APP_URL', 'http://localhost:5173')
  end
end
