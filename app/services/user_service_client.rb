class UserServiceClient
  include HTTParty

  base_uri ENV.fetch('USER_SERVICE_URL', 'http://localhost:3001')

  def self.find_user(id)
    response = get("/api/v1/users/#{id}")
    handle_response(response)
  end

  def self.update_user(id, params)
    response = put("/api/v1/users/#{id}",
                   body: { user: params }.to_json,
                   headers: { 'Content-Type' => 'application/json' }
    )
    handle_response(response)
  end

  def self.auto_complete_users(term)
    response = get("/api/v1/users/auto_complete", query: { term: term })
    handle_response(response)
  end

  def self.change_password(id, current_password:, password:, password_confirmation:)
    response = put("/api/v1/users/#{id}/change_password",
                   body: {
                     current_password: current_password,
                     password: password,
                     password_confirmation: password_confirmation
                   }.to_json,
                   headers: { 'Content-Type' => 'application/json' }
    )
    handle_response(response)
  end

  # New: set/update user preferences (locale)
  def self.set_locale(id, locale:)
    response = put("/api/v1/users/#{id}/preferences",
                   body: { preference: { locale: locale } }.to_json,
                   headers: { 'Content-Type' => 'application/json' }
    )
    handle_response(response)
  end

  # New: upload avatar or toggle gravatar
  # If use_gravatar is true, service should switch to gravatar; otherwise upload file in multipart
  def self.upload_avatar(id, file: nil, use_gravatar: false)
    if use_gravatar
      response = put("/api/v1/users/#{id}/avatar",
                     body: { gravatar: true }.to_json,
                     headers: { 'Content-Type' => 'application/json' }
      )
    else
      # Multipart upload; HTTParty will set the proper multipart boundary for File instances
      response = post("/api/v1/users/#{id}/avatar",
                      body: { avatar: file },
                      headers: { 'Content-Type' => 'multipart/form-data' }
      )
    end
    handle_response(response)
  end

  private

  def self.handle_response(response)
    case response.code
    when 200..299
      response.parsed_response
    when 404
      nil
    else
      raise "User Service Error: #{response.code} - #{response.message}"
    end
  end
end