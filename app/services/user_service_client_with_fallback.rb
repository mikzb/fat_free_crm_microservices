class UserServiceClientWithFallback
  include CircuitBreaker

  def initialize
  end

  def find_user(id)
    call_user_service_find(id)
  rescue => e
    Rails.logger.error "User service failed, falling back to direct DB: #{e.message}"
    # Fallback to direct database access
    user = User.find(id)
    format_user_response(user)
  end

  def update_user(id, params)
    call_user_service_update(id, params)
  rescue => e
    Rails.logger.error "User service failed for update: #{e.message}"
    # Fallback to original controller logic
    user = User.find(id)
    user.update(params)
    format_user_response(user)
  end

  private

  def call_user_service_find(id)
    UserServiceClient.find_user(id)
  end

  def call_user_service_update(id, params)
    UserServiceClient.update_user(id, params)
  end

  def format_user_response(user)
    {
      'data' => {
        'id' => user.id.to_s,
        'attributes' => user.attributes
      }
    }
  end

  # Configure circuit breaker for the service calls
  circuit_method :call_user_service_find
  circuit_method :call_user_service_update

  # Optional configuration
  circuit_handler do |handler|
    handler.failure_threshold = 3
    handler.failure_timeout = 30
    handler.excluded_exceptions = [] # Add any exceptions that shouldn't trigger the circuit
  end
end