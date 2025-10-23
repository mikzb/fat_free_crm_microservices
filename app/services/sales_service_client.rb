class SalesServiceClient
  include HTTParty

  base_uri ENV.fetch('USER_SERVICE_URL', 'http://localhost:3001')

  class << self
    # Shared helpers
    def json_body(hash)
      { body: hash.to_json, headers: { 'Content-Type' => 'application/json' } }
    end

    def handle_response(response)
      case response.code
      when 200..299
        response.parsed_response
      when 404
        nil
      else
        raise "Sales Service Error: #{response.code} - #{response.message}"
      end
    end

    # Campaigns
    def list_campaigns(params = {})
      handle_response get('/api/v1/campaigns', query: params)
    end

    def get_campaign(id)
      handle_response get("/api/v1/campaigns/#{id}")
    end

    def create_campaign(attrs)
      handle_response post('/api/v1/campaigns', json_body(campaign: attrs))
    end

    def update_campaign(id, attrs)
      handle_response put("/api/v1/campaigns/#{id}", json_body(campaign: attrs))
    end

    def destroy_campaign(id)
      handle_response delete("/api/v1/campaigns/#{id}")
    end

    # Leads
    def list_leads(params = {})
      handle_response get('/api/v1/leads', query: params)
    end

    def get_lead(id)
      handle_response get("/api/v1/leads/#{id}")
    end

    def create_lead(attrs)
      handle_response post('/api/v1/leads', json_body(lead: attrs))
    end

    def update_lead(id, attrs)
      handle_response put("/api/v1/leads/#{id}", json_body(lead: attrs))
    end

    def destroy_lead(id)
      handle_response delete("/api/v1/leads/#{id}")
    end

    def promote_lead(id, payload)
      handle_response put("/api/v1/leads/#{id}/promote", json_body(payload))
    end

    def reject_lead(id)
      handle_response put("/api/v1/leads/#{id}/reject")
    end

    # Contacts
    def list_contacts(params = {})
      handle_response get('/api/v1/contacts', query: params)
    end

    def get_contact(id)
      handle_response get("/api/v1/contacts/#{id}")
    end

    def create_contact(attrs)
      handle_response post('/api/v1/contacts', json_body(contact: attrs))
    end

    def update_contact(id, attrs)
      handle_response put("/api/v1/contacts/#{id}", json_body(contact: attrs))
    end

    def destroy_contact(id)
      handle_response delete("/api/v1/contacts/#{id}")
    end

    # Opportunities
    def list_opportunities(params = {})
      handle_response get('/api/v1/opportunities', query: params)
    end

    def get_opportunity(id)
      handle_response get("/api/v1/opportunities/#{id}")
    end

    def create_opportunity(attrs)
      handle_response post('/api/v1/opportunities', json_body(opportunity: attrs))
    end

    def update_opportunity(id, attrs)
      handle_response put("/api/v1/opportunities/#{id}", json_body(opportunity: attrs))
    end

    def destroy_opportunity(id)
      handle_response delete("/api/v1/opportunities/#{id}")
    end
  end
end