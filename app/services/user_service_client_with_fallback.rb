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

  def change_password(id, current_password:, password:, password_confirmation:)
    call_user_service_change_password(id, current_password: current_password, password: password, password_confirmation: password_confirmation)
  rescue => e
    Rails.logger.error "User service failed for change_password: #{e.message}"
    user = User.find(id)
    if user.valid_password?(current_password)
      if password.blank?
        { 'status' => 'noop', 'message' => I18n.t(:msg_password_not_changed) }
      else
        user.password = password
        user.password_confirmation = password_confirmation
        user.save
        { 'status' => 'ok', 'message' => I18n.t(:msg_password_changed) }
      end
    else
      { 'status' => 'error', 'errors' => { 'current_password' => [I18n.t(:msg_invalid_password)] } }
    end
  end

    def upload_avatar(id, file: nil, use_gravatar: false)
    call_user_service_upload_avatar(id, file: file, use_gravatar: use_gravatar)
  rescue => e
    Rails.logger.error "User service failed for upload_avatar: #{e.message}"
    user = User.find(id)

    if use_gravatar
      user.avatar = nil
      user.save
      return { 'status' => 'ok' }
    end

    if file
      avatar = Avatar.create(image: file, entity: user, user_id: user.id)
      if avatar.valid?
        user.avatar = avatar
        user.save
        { 'status' => 'ok' }
      else
        # mirror current behavior, surface a unified error
        { 'status' => 'error', 'errors' => { 'image' => [I18n.t(:msg_bad_image_file)] } }
      end
    else
      { 'status' => 'noop' }
    end
  end

  private

  def call_user_service_find(id)
    UserServiceClient.find_user(id)
  end

  def call_user_service_update(id, params)
    UserServiceClient.update_user(id, params)
  end

  def auto_complete_users(term)
    UserServiceClient.auto_complete_users(term)
  end

  def call_user_service_change_password(id, current_password:, password:, password_confirmation:)
    UserServiceClient.change_password(id, current_password: current_password, password: password, password_confirmation: password_confirmation)
  end

  def call_user_service_upload_avatar(id, file:, use_gravatar:)
    UserServiceClient.upload_avatar(id, file: file, use_gravatar: use_gravatar)
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
  circuit_method :auto_complete_users
  circuit_method :call_user_service_change_password
  circuit_method :call_user_service_upload_avatar

  # Optional configuration
  circuit_handler do |handler|
    handler.failure_threshold = 3
    handler.failure_timeout = 30
    handler.excluded_exceptions = [] # Add any exceptions that shouldn't trigger the circuit
  end
end