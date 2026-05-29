# frozen_string_literal: true

# Handles the authenticated email change flow: issuing change tokens to the new
# address and consuming them. The user's email is NOT updated until they click
# the link sent to the new address: keeping the existing email active prevents
# lockout if the new address is mistyped.
class EmailChangeService
  def self.request_change(teacher, new_email)
    new(teacher: teacher, new_email: new_email).request_change
  end

  def self.confirm(token)
    new(token: token).confirm
  end

  def initialize(teacher: nil, new_email: nil, token: nil)
    @teacher = teacher
    @new_email = new_email
    @token = token
  end

  def request_change
    normalized = @new_email.to_s.downcase.strip

    return invalid_email_result unless valid_format?(normalized)
    return same_email_result if normalized == @teacher.email.downcase
    return email_taken_result if email_taken?(normalized)

    @teacher.generate_email_change_token!(normalized)
    EmailChangeMailer.change_request_email(@teacher).deliver_later
    Rails.logger.info("Email change requested for teacher #{@teacher.id}: confirmation link sent to #{normalized}")

    { success: true }
  end

  def confirm
    return invalid_token_result if @token.blank?

    teacher = Teacher.find_by(email_change_token: @token)
    return invalid_token_result if teacher.nil?
    return invalid_token_result unless teacher.email_change_token_valid?

    if email_taken_by_other?(teacher)
      teacher.clear_email_change!
      return { success: false, error: 'That email is no longer available.' }
    end

    if teacher.confirm_email_change!
      { success: true, teacher: teacher }
    else
      { success: false, validation_errors: teacher }
    end
  end

  private

  def valid_format?(email)
    email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def email_taken?(email)
    Teacher.where.not(id: @teacher.id).exists?(email: email)
  end

  def email_taken_by_other?(teacher)
    Teacher.where.not(id: teacher.id).exists?(email: teacher.pending_email.to_s.downcase)
  end

  def invalid_email_result
    { success: false, error: 'Please enter a valid email address.' }
  end

  def same_email_result
    { success: false, error: 'That is already your current email.' }
  end

  def email_taken_result
    { success: false, error: 'That email is already in use.' }
  end

  def invalid_token_result
    { success: false, error: 'This confirmation link is invalid or has expired. Please request a new email change.' }
  end
end
