class UserServiceClientWithFallback

  def initialize
    @circuit_breaker = CircuitBreaker.new do |cb|
      cb.failure_threshold = 3
      cb.recovery_timeout = 30
      cb.expected_exception = StandardError
    end
  end

  def find_user(id)
    @circuit_breaker.call do
      UserServiceClient.find_user(id)
    end
  rescue => e
    Rails.logger.error "User service failed, falling back to direct DB: #{e.message}"
    # Fallback to direct database access
    user = User.find(id)
    format_user_response(user)
  end

  def update_user(id, params)
    @circuit_breaker.call do
      UserServiceClient.update_user(id, params)
    end
  rescue => e
    Rails.logger.error "User service failed for update: #{e.message}"
    # Fallback to original controller logic
    user = User.find(id)
    user.update(params)
    format_user_response(user)
  end

  private

  def format_user_response(user)
    {
      'data' => {
        'id' => user.id.to_s,
        'attributes' => user.attributes
      }
    }
  end
end