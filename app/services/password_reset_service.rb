# frozen_string_literal: true

# Handles the forgot-password flow: issuing reset tokens and consuming them.
#
# Privacy note: request_reset always reports success to the caller, even when no
# account matches the email. This prevents account enumeration (an attacker
# probing which emails are registered). When the email is unknown we record a
# warning in the log and take no further action: no token is set, no mail is sent.
class PasswordResetService
  def self.request_reset(email)
    new(email: email).request_reset
  end

  def self.reset(token, password)
    new(token: token, password: password).reset
  end

  def initialize(email: nil, token: nil, password: nil)
    @email = email
    @token = token
    @password = password
  end

  def request_reset
    teacher = Teacher.find_by_email(@email.to_s)

    if teacher
      teacher.generate_password_reset_token!
      PasswordResetMailer.reset_email(teacher).deliver_later
      Rails.logger.info("Password reset requested: reset link sent to #{teacher.email}")
    else
      Rails.logger.warn(
        "Password reset requested for non-existent email: #{@email} - no account found, no reset link sent"
      )
    end

    # Always success: the caller must not be able to tell whether the email exists.
    { success: true }
  end

  def reset
    return invalid_token_result if @token.blank?

    teacher = Teacher.find_by(password_reset_token: @token)
    return invalid_token_result if teacher.nil?
    return invalid_token_result unless teacher.password_reset_token_valid?

    teacher.password = @password

    if teacher.save
      teacher.clear_password_reset_token!
      { success: true, teacher: teacher }
    else
      { success: false, validation_errors: teacher }
    end
  end

  private

  def invalid_token_result
    { success: false, error: 'This reset link is invalid or has expired. Please request a new one.' }
  end
end
