class AdminServiceClient
  include HTTParty

  base_uri ENV.fetch('USER_SERVICE_URL', 'http://localhost:3001')

  class << self
    # ----------------------------
    # Public Admin Users endpoints
    # ----------------------------
    def list_users(page: nil, per_page: nil, q: nil, query: nil)
      params = {}
      params[:page] = page if page
      params[:per_page] = per_page if per_page
      params[:q] = q if q
      params[:query] = query if query
      auth_get('/api/v1/admin/users', query: params)
    end

    def get_user(id)
      auth_get("/api/v1/admin/users/#{id}")
    end

    def create_user(params)
      auth_post('/api/v1/admin/users', json_body(user: params))
    end

    def update_user(id, params)
      auth_put("/api/v1/admin/users/#{id}", json_body(user: params))
    end

    def destroy_user(id)
      auth_delete("/api/v1/admin/users/#{id}")
    end

    def suspend_user(id)
      auth_put("/api/v1/admin/users/#{id}/suspend")
    end

    def reactivate_user(id)
      auth_put("/api/v1/admin/users/#{id}/reactivate")
    end

    # ----------------------------
    # Public Admin Groups endpoints
    # ----------------------------
    def list_groups(page: nil, per_page: nil)
      params = {}
      params[:page] = page if page
      params[:per_page] = per_page if per_page
      auth_get('/api/v1/admin/groups', query: params)
    end

    def get_group(id)
      auth_get("/api/v1/admin/groups/#{id}")
    end

    def create_group(params)
      auth_post('/api/v1/admin/groups', json_body(group: params))
    end

    def update_group(id, params)
      auth_put("/api/v1/admin/groups/#{id}", json_body(group: params))
    end

    def destroy_group(id)
      auth_delete("/api/v1/admin/groups/#{id}")
    end

    # ----------------------------
    # Token/JWKS management
    # ----------------------------
    def reset_caches!
      @token = nil
      @token_exp = nil
      @token_type = 'Bearer'
      @jwks = nil
      @jwks_fetched_at = nil
      @jwks_by_kid = {}
    end

    private

    # ---------- Authenticated request wrappers with auto-retry ----------
    def auth_get(path, query: nil)
      with_auth_retry { get(path, headers: auth_headers, query: query) }
    end

    def auth_post(path, body: nil, headers: {}, query: nil)
      with_auth_retry { post(path, headers: auth_headers.merge(headers), body: body, query: query) }
    end

    def auth_put(path, body: nil, headers: {}, query: nil)
      with_auth_retry { put(path, headers: auth_headers.merge(headers), body: body, query: query) }
    end

    def auth_delete(path, headers: {}, query: nil)
      with_auth_retry { delete(path, headers: auth_headers.merge(headers), query: query) }
    end

    def with_auth_retry
      ensure_token!
      response = yield
      return handle_response(response) if response.code.between?(200, 299)

      if response.code == 401 || response.code == 403
        obtain_token!
        response = yield
      end

      handle_response(response)
    rescue => e
      raise "Admin Service Error: #{e.message}"
    end

    # ---------------- JWT handling ----------------
    def auth_headers
      ensure_token!
      { 'Authorization' => "#{@token_type} #{@token}" }
    end

    def ensure_token!
      return if @token && @token_exp && Time.now < @token_exp
      obtain_token!
    end

    def obtain_token!
      email = ENV['USER_SERVICE_ADMIN_EMAIL']
      password = ENV['USER_SERVICE_ADMIN_PASSWORD']
      raise 'Missing USER_SERVICE_ADMIN_EMAIL/PASSWORD' if email.to_s.empty? || password.to_s.empty?

      resp = post('/api/v1/admin/tokens',
                  headers: { 'Content-Type' => 'application/json' },
                  body: { email: email, password: password }.to_json)

      parsed = handle_response(resp)
      token       = parsed.is_a?(Hash) ? (parsed['token'] || parsed[:token]) : nil
      token_type  = parsed.is_a?(Hash) ? (parsed['token_type'] || parsed[:token_type]) : 'Bearer'
      expires_in  = parsed.is_a?(Hash) ? (parsed['expires_in'] || parsed[:expires_in]) : nil

      raise 'Token missing from admin/tokens response' if token.to_s.empty?

      @token = token
      @token_type = token_type.to_s.empty? ? 'Bearer' : token_type
      @token_exp = if expires_in
                     Time.now + expires_in.to_i
                   else
                     Time.now + 600
                   end
    end

    # ---------------- JWKS handling (fetch/cache) ----------------
    # JWKS shape: { keys: [ { kty, use, kid, alg, n, e } ] }
    def ensure_jwks!
      ttl = (ENV['USER_SERVICE_JWKS_REFRESH_SECONDS'] || '900').to_i
      if @jwks.nil? || @jwks_fetched_at.nil? || (Time.now - @jwks_fetched_at) > ttl
        fetch_jwks!
      end
    end

    def fetch_jwks!
      resp = get('/api/v1/jwks')
      parsed = handle_response(resp)
      keys = parsed.is_a?(Hash) ? (parsed['keys'] || parsed[:keys]) : nil
      raise 'Invalid JWKS payload' unless keys.is_a?(Array)

      @jwks_by_kid = {}
      keys.each do |k|
        kid = k['kid'] || k[:kid]
        @jwks_by_kid[kid] = k if kid
      end
      @jwks = parsed
      @jwks_fetched_at = Time.now
      @jwks
    end

    # Utility to send JSON
    def json_body(hash)
      { body: hash.to_json, headers: { 'Content-Type' => 'application/json' } }
    end

    # Unified response handler
    def handle_response(response)
      case response.code
      when 200..299
        response.parsed_response
      when 401
        raise '401 unauthorized'
      when 403
        raise '403 forbidden'
      when 404
        nil
      else
        raise "HTTP #{response.code} - #{response.message}"
      end
    end
  end
end