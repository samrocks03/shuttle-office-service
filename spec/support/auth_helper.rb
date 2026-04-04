# frozen_string_literal: true

module AuthHelper
  def auth_headers(user = nil)
    user ||= create(:user)
    token = JWT.encode({ user_id: user.id, user_uid: user.uid }, Rails.application.credentials[:secret_key_base])
    { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
  end

  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
