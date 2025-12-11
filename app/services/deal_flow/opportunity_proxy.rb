module DealFlow
  class OpportunityProxy
    include HTTParty
    include ActiveModel::Model

    base_uri 'http://localhost:3001/api/v1'

    # Define the core attributes we actually USE in the view
    attr_accessor :id, :name, :stage, :probability, :amount, :user_id,
                  :account_id, :created_at, :updated_at, :closes_on,
                  :assigned_to
    def to_partial_path
      "opportunities/opportunity"
    end

    def self.model_name
      ActiveModel::Name.new(self, nil, "Opportunity")
    end



    # 1. OVERRIDE INITIALIZE to safely handle extra data
    def initialize(attributes = {})
      attributes.each do |name, value|
        # Only set the value if our Proxy class has that attribute defined
        send("#{name}=", value) if respond_to?("#{name}=")
      end
    end

    def created_at
      parse_time(@created_at)
    end

    def updated_at
      parse_time(@updated_at)
    end

    # 3. OVERRIDE THE GETTER for Date fields (closes_on)


    # HYDRATION: The View expects `opportunity.account.name`.
    # Since the service only sent us `account_id`, we cheat and look it up locally
    # because we share the database!
    def account
      @account ||= ::Account.find_by(id: account_id)
    end

    # Hydrate the User (Assignee)
    def assignee
      @assignee ||= ::User.find_by(id: assigned_to)
    end

    # Hydrate the Creator (if distinct)
    def user
      @user ||= ::User.find_by(id: user_id)
    end

    # Helper for ActiveModel compliance
    def persisted?
      id.present?
    end

    # Class Method: Fetch List
    def self.all_for_user(user)
      response = get('/opportunities', query: { user_id: user.id })
      if response.success?
        JSON.parse(response.body).map { |attrs| new(attrs) }
      else
        [] # Fallback to empty array on error
      end
    end

    def closes_on
      return nil if @closes_on.blank?
      return @closes_on if @closes_on.is_a?(Date) || @closes_on.is_a?(Time)
      Date.parse(@closes_on) rescue nil
    end

    private

    def parse_time(value)
      return nil if value.blank?
      return value if value.is_a?(Time) || value.is_a?(DateTime)

      # Time.parse converts the string "2023-..." into a Time object
      Time.zone.parse(value) rescue Time.parse(value) rescue nil
    end


  end
end