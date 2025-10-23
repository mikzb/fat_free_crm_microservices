class CampaignsController < EntitiesController
  before_action :get_data_for_sidebar, only: :index

  # GET /campaigns
  #----------------------------------------------------------------------------
  def index
    if use_sales_service?
      begin
        resp = SalesServiceClient.list_campaigns(page: page_param, per_page: per_page_param, query: params[:query], q: params[:q])
        @service_campaigns = resp && (resp['data'] || resp[:data])
      rescue => e
        Rails.logger.error "Sales service list_campaigns failed: #{e.message}"
      end
    end

    @campaigns = get_campaigns(page: page_param, per_page: per_page_param)

    respond_with @campaigns do |format|
      format.xls { render layout: 'header' }
      format.csv { render csv: @campaigns }
    end
  end

  # GET /campaigns/1
  #----------------------------------------------------------------------------
  def show
    if use_sales_service?
      begin
        @service_campaign = SalesServiceClient.get_campaign(@campaign.id)
      rescue => e
        Rails.logger.error "Sales service get_campaign failed: #{e.message}"
      end
    end

    respond_with(@campaign) do |format|
      format.html do
        @stage = Setting.unroll(:opportunity_stage)
        @comment = Comment.new
        @timeline = timeline(@campaign)
      end
      format.js do
        @stage = Setting.unroll(:opportunity_stage)
        @comment = Comment.new
        @timeline = timeline(@campaign)
      end
      format.xls do
        @leads = @campaign.leads
        render '/leads/index', layout: 'header'
      end
      format.csv { render csv: @campaign.leads }
      format.rss { @items = "leads"; @assets = @campaign.leads }
      format.atom { @items = "leads"; @assets = @campaign.leads }
    end
  end

  # POST /campaigns
  #----------------------------------------------------------------------------
  def create
    @comment_body = params[:comment_body]

    if use_sales_service?
      begin
        SalesServiceClient.create_campaign(resource_params.to_h)
        flash[:notice] = t(:msg_asset_created, @campaign.name) rescue nil
      rescue => e
        Rails.logger.error "Sales service create_campaign failed: #{e.message}"
        @campaign.errors.add(:base, 'External service error')
      end
      return respond_with(@campaign)
    end

    respond_with(@campaign) do |_format|
      if @campaign.save
        @campaign.add_comment_by_user(@comment_body, current_user)
        @campaigns = get_campaigns
        get_data_for_sidebar
      end
    end
  end

  # PUT /campaigns/1
  #----------------------------------------------------------------------------
  def update
    if use_sales_service?
      begin
        SalesServiceClient.update_campaign(@campaign.id, resource_params.to_h)
        flash[:notice] = t(:msg_asset_updated, @campaign.name) rescue nil
      rescue => e
        Rails.logger.error "Sales service update_campaign failed: #{e.message}"
        @campaign.errors.add(:base, 'External service error')
      end
      return respond_with(@campaign)
    end

    respond_with(@campaign) do |_format|
      @campaign.access = resource_params[:access] if resource_params[:access]
      get_data_for_sidebar if @campaign.update(resource_params) && called_from_index_page?
    end
  end

  # DELETE /campaigns/1
  #----------------------------------------------------------------------------
  def destroy
    if use_sales_service?
      begin
        SalesServiceClient.destroy_campaign(@campaign.id)
        flash[:notice] = t(:msg_asset_deleted, @campaign.name) rescue nil
      rescue => e
        Rails.logger.error "Sales service destroy_campaign failed: #{e.message}"
        @campaign.errors.add(:base, 'External service error')
      end
      return respond_with(@campaign) { |format| format.html { redirect_to campaigns_path } }
    end

    @campaign.destroy
    respond_with(@campaign) do |format|
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
  end

  private

  alias get_campaigns get_list_of_records

  def list_includes
    %i[tags].freeze
  end

  def use_sales_service?
    ENV['USE_SALES_SERVICE'] == 'true' || params[:use_service] == 'true'
  end
end