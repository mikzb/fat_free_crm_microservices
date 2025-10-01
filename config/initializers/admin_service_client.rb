Rails.application.config.to_prepare do
  begin
    AdminServiceClient.__send__(:ensure_jwks!)
  rescue => e
    Rails.logger.warn "AdminServiceClient JWKS warm-up failed: #{e.message}"
  end

  begin
    AdminServiceClient.__send__(:ensure_token!)
  rescue => e
    Rails.logger.warn "AdminServiceClient token warm-up failed: #{e.message}"
  end
end