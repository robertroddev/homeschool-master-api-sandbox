# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAILER_FROM', 'Homeschool Master <support@homeschoolmaster.com>')
  layout 'mailer'
end
