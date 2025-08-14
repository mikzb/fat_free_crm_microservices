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