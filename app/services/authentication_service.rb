# frozen_string_literal: true

class AuthenticationService
  def self.call(email, password)
    new(email, password).call
  end

  def initialize(email = nil, password = nil, refresh_token = nil)
    @email = email
    @password = password
    @refresh_token = refresh_token
  end

  def call
    @teacher = Teacher.find_by(email: @email)

    error = validate_teacher_exists || validate_password || validate_active
    return error if error

    { success: true, teacher: @teacher }
  end

  def self.refresh(refresh_token)
    new(nil, nil, refresh_token).validate_refresh
  end

  def validate_refresh
    error = validate_token_decoded || validate_token_in_database || validate_token_active
    return error if error

    { success: true, teacher_id: @token_record.teacher_id }
  end

  private

  def validate_teacher_exists
    return if @teacher

    Rails.logger.warn("Login failed: email not found - #{@email}")
    { success: false, error: 'Invalid email or password' }
  end

  def validate_password
    return if @teacher.authenticate(@password)

    Rails.logger.warn("Login failed: wrong password - #{@teacher.email}")
    { success: false, error: 'Invalid email or password' }
  end

  def validate_active
    return if @teacher.is_active?

    Rails.logger.warn("Login failed: inactive account - #{@teacher.email}")
    { success: false, error: 'Account is deactivated' }
  end

  def validate_token_decoded
    @decoded = JwtService.decode_refresh_token(@refresh_token)
    return if @decoded

    Rails.logger.warn('Refresh failed: invalid or expired token')
    { success: false, error: 'Invalid refresh token' }
  end

  def validate_token_in_database
    @token_record = RefreshToken.find_by(token: @refresh_token)
    return if @token_record

    Rails.logger.warn("Refresh failed: token not found in database - #{@decoded[:jti]}")
    { success: false, error: 'Invalid refresh token' }
  end

  def validate_token_active
    return if @token_record.valid_token?

    Rails.logger.warn("Refresh failed: token revoked or expired - #{@token_record.jti}")
    { success: false, error: 'Invalid refresh token' }
  end
end
