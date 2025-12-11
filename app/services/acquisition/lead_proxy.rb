module Acquisition
  class LeadProxy
    include HTTParty
    include ActiveModel::Model

    base_uri 'http://localhost:3002/api/v1'

    # 1. EXPANDED Attribute List (Added referred_by, blog, skype, etc.)
    # We define these in a constant so we can loop over them later.
    CORE_ATTRIBUTES = [
      :id, :user_id, :campaign_id, :assigned_to,
      :first_name, :last_name, :access, :title, :company,
      :source, :status, :email, :alt_email, :phone, :mobile,
      :rating, :do_not_call, :created_at, :updated_at,
      :background_info, :referred_by, :blog, :linkedin, :facebook, :twitter, :skype
    ]

    attr_accessor(*CORE_ATTRIBUTES)

    # 2. META-PROGRAMMING MAGIC (The Fix)
    # This loop automatically creates the 'def field?' methods for everything above.
    CORE_ATTRIBUTES.each do |attr|
      define_method("#{attr}?") do
        send(attr).present?
      end
    end

    # 3. Initialize (Standard)
    def initialize(attributes = {})
      attributes.each do |name, value|
        send("#{name}=", value) if respond_to?("#{name}=")
      end
    end

    # 4. View Compliance
    def to_partial_path; "leads/lead"; end
    def self.model_name; ActiveModel::Name.new(self, nil, "Lead"); end
    def persisted?; id.present?; end

    # 5. Helpers
    def full_name(format = nil)
      if format.nil? || format == "before"
        "#{first_name} #{last_name}"
      else
        "#{last_name}, #{first_name}"
      end
    end
    alias :name :full_name

    # 6. Hydration
    def user
      @user ||= ::User.find_by(id: user_id)
    end

    def assignee
      @assignee ||= ::User.find_by(id: assigned_to)
    end

    def campaign
      @campaign ||= ::Campaign.find_by(id: campaign_id)
    end

    # 7. Type Casting
    def created_at; parse_time(@created_at); end
    def updated_at; parse_time(@updated_at); end

    # Stubs
    def tags; []; end
    def tag_list; []; end

    private

    def parse_time(value)
      return nil if value.blank?
      return value if value.is_a?(Time)
      Time.zone.parse(value) rescue Time.parse(value) rescue nil
    end

    def self.all_for_user(user)
      response = get('/leads', query: { user_id: user.id })
      if response.success?
        JSON.parse(response.body).map { |attrs| new(attrs) }
      else
        []
      end
    end
  end
end