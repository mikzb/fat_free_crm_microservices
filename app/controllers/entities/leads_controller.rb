class LeadsController < EntitiesController
  before_action :get_data_for_sidebar, only: :index
  autocomplete :account, :name, full: true

  # GET /leads
  #----------------------------------------------------------------------------
  def index
    if use_sales_service?
      begin
        resp = SalesServiceClient.list_leads(page: page_param, per_page: per_page_param, query: params[:query], q: params[:q])
        @service_leads = resp && (resp['data'] || resp[:data])
      rescue => e
        Rails.logger.error "Sales service list_leads failed: #{e.message}"
      end
    end
    @leads = get_leads(page: page_param)

    respond_with @leads do |format|
      format.xls { render layout: 'header' }
      format.csv { render csv: @leads }
    end
  end

  # GET /leads/1
  #----------------------------------------------------------------------------
  def show
    if use_sales_service?
      begin
        @service_lead = SalesServiceClient.get_lead(@lead.id)
      rescue => e
        Rails.logger.error "Sales service get_lead failed: #{e.message}"
      end
    end
    @comment = Comment.new
    @timeline = timeline(@lead)
    respond_with(@lead)
  end

  # POST /leads
  #----------------------------------------------------------------------------
  def create
    if use_sales_service?
      begin
        SalesServiceClient.create_lead(resource_params.to_h)
        flash[:notice] = t(:msg_asset_created, @lead.full_name) rescue nil
      rescue => e
        Rails.logger.error "Sales service create_lead failed: #{e.message}"
        @lead.errors.add(:base, 'External service error')
      end
      return respond_with(@lead)
    end

    get_campaigns
    @comment_body = params[:comment_body]
    respond_with(@lead) do |_format|
      if @lead.save_with_permissions(params.permit!)
        @lead.add_comment_by_user(@comment_body, current_user)
        if called_from_index_page?
          @leads = get_leads
          get_data_for_sidebar
        else
          get_data_for_sidebar(:campaign)
        end
      end
    end
  end

  # PUT /leads/1
  #----------------------------------------------------------------------------
  def update
    if use_sales_service?
      begin
        SalesServiceClient.update_lead(@lead.id, resource_params.to_h)
        flash[:notice] = t(:msg_asset_updated, @lead.full_name) rescue nil
      rescue => e
        Rails.logger.error "Sales service update_lead failed: #{e.message}"
        @lead.errors.add(:base, 'External service error')
      end
      return respond_with(@lead)
    end

    respond_with(@lead) do |_format|
      @lead.access = resource_params[:access] if resource_params[:access]
      if @lead.update_with_lead_counters(resource_params)
        update_sidebar
      else
        @campaigns = Campaign.my(current_user).order('name')
      end
    end
  end

  # DELETE /leads/1
  #----------------------------------------------------------------------------
  def destroy
    if use_sales_service?
      begin
        SalesServiceClient.destroy_lead(@lead.id)
        flash[:notice] = t(:msg_asset_deleted, @lead.full_name) rescue nil
      rescue => e
        Rails.logger.error "Sales service destroy_lead failed: #{e.message}"
        @lead.errors.add(:base, 'External service error')
      end
      return respond_with(@lead) { |format| format.html { redirect_to leads_path } }
    end

    @lead.destroy
    respond_with(@lead) do |format|
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
  end

  # PUT /leads/1/promote
  #----------------------------------------------------------------------------
  def promote
    if use_sales_service?
      begin
        SalesServiceClient.promote_lead(@lead.id, params.permit!.to_h)
        flash[:notice] = t(:msg_asset_promoted, @lead.full_name) rescue nil
      rescue => e
        Rails.logger.error "Sales service promote_lead failed: #{e.message}"
        @lead.errors.add(:base, 'External service error')
      end
      return respond_with(@lead)
    end

    @account, @opportunity, @contact = @lead.promote(params.permit!)
    @accounts = Account.my(current_user).order('name')
    @stage = Setting.unroll(:opportunity_stage)
    respond_with(@lead) do |format|
      if @account.errors.empty? && @opportunity.errors.empty? && @contact.errors.empty?
        @lead.convert
        update_sidebar
      else
        format.json { render json: @account.errors + @opportunity.errors + @contact.errors, status: :unprocessable_entity }
        format.xml  { render xml: @account.errors + @opportunity.errors + @contact.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /leads/1/reject
  #----------------------------------------------------------------------------
  def reject
    if use_sales_service?
      begin
        SalesServiceClient.reject_lead(@lead.id)
        flash[:notice] = t(:msg_asset_rejected, @lead.full_name) rescue nil
      rescue => e
        Rails.logger.error "Sales service reject_lead failed: #{e.message}"
        @lead.errors.add(:base, 'External service error')
      end
      return respond_with(@lead)
    end

    @lead.reject
    update_sidebar
    respond_with(@lead) do |format|
      format.html do
        flash[:notice] = t(:msg_asset_rejected, @lead.full_name)
        redirect_to leads_path
      end
    end
  end

  private

  alias get_leads get_list_of_records

  def list_includes
    %i[tags].freeze
  end

  def get_campaigns
    @campaigns = Campaign.my(current_user).order('name')
  end

  def use_sales_service?
    ENV['USE_SALES_SERVICE'] == 'true' || params[:use_service] == 'true'
  end
end