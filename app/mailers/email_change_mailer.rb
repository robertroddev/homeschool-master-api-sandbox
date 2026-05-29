# frozen_string_literal: true

class EmailChangeMailer < ApplicationMailer
  # Sent to the NEW address (teacher.pending_email), not the current one: the
  # link is what proves the user owns the new inbox.
  def change_request_email(teacher)
    @teacher = teacher
    @confirm_url = "#{web_app_url}/confirm-email-change?token=#{teacher.email_change_token}"

    mail(
      to: teacher.pending_email,
      subject: 'Confirm your new Homeschool Master email'
    )
  end

  private

  def web_app_url
    ENV.fetch('WEB_APP_URL', 'http://localhost:5173')
  end
end
