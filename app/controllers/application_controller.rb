# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :deep_snake_case_params

  private

  def deep_snake_case_params
    request.parameters.deep_transform_keys!(&:underscore)
  end
end
