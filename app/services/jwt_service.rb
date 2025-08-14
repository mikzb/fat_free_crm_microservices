# app/services/jwt_service.rb
class JwtService
  SECRET_KEY = Rails.application.credentials.secret_key_base || 'your-secret-key'
  ALGORITHM = 'HS256'

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM })[0]
    HashWithIndifferentAccess.new(decoded)
  rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError => e
    Rails.logger.error "JWT decode error: #{e.message}"
    nil
  end

  def self.user_token_with_permissions(user)
    encode({
             user_id: user.id,
             email: user.email,
             username: user.username,
             admin: user.admin?,
             # Add any other roles or permissions you need
             roles: user.roles&.pluck(:name) || [],
             iat: Time.current.to_i
           })
  end
end