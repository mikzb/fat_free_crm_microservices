class OpportunitiesController < EntitiesController
  before_action :load_settings
  before_action :get_data_for_sidebar, only: :index
  before_action :set_params, only: %i[index redraw filter]

  # GET /opportunities
  #----------------------------------------------------------------------------
  def index
    if use_sales_service?
      begin
        resp = SalesServiceClient.list_opportunities(page: page_param, per_page: per_page_param, query: params[:query], q: params[:q])
        @service_opportunities = resp && (resp['data'] || resp[:data])
      rescue => e
        Rails.logger.error "Sales service list_opportunities failed: #{e.message}"
      end
    end

    @opportunities = get_opportunities(page: page_param, per_page: per_page_param)

    respond_with @opportunities do |format|
      format.xls { render layout: 'header' }
      format.csv { render csv: @opportunities }
    end
  end

  # GET /opportunities/1
  #----------------------------------------------------------------------------
  def show
    if use_sales_service?
      begin
        @service_opportunity = SalesServiceClient.get_opportunity(@opportunity.id)
      rescue => e
        Rails.logger.error "Sales service get_opportunity failed: #{e.message}"
      end
    end
    @comment = Comment.new
    @timeline = timeline(@opportunity)
    respond_with(@opportunity)
  end

  # POST /opportunities
  #----------------------------------------------------------------------------
  def create
    if use_sales_service?
      begin
        SalesServiceClient.create_opportunity(params.require(:opportunity).permit!.to_h.merge(account: params[:account], campaign: params[:campaign], contact: params[:contact]))
        flash[:notice] = t(:msg_asset_created, @opportunity.name) rescue nil
      rescue => e
        Rails.logger.error "Sales service create_opportunity failed: #{e.message}"
        @opportunity.errors.add(:base, 'External service error')
      end
      return respond_with(@opportunity)
    end

    @comment_body = params[:comment_body]
    respond_with(@opportunity) do |_format|
      if @opportunity.save_with_account_and_permissions(params.permit!)
        @opportunity.add_comment_by_user(@comment_body, current_user)
        if called_from_index_page?
          @opportunities = get_opportunities
          get_data_for_sidebar
        elsif called_from_landing_page?(:accounts)
          get_data_for_sidebar(:account)
        elsif called_from_landing_page?(:campaigns)
          get_data_for_sidebar(:campaign)
        end
      else
        @accounts = Account.my(current_user).order('name')
        @account = guess_related_account(params[:account][:id], request.referer, current_user)
        @contact = Contact.find(params[:contact]) unless params[:contact].blank?
        @campaign = Campaign.find(params[:campaign]) unless params[:campaign].blank?
      end
    end
  end

  # PUT /opportunities/1
  #----------------------------------------------------------------------------
  def update
    if use_sales_service?
      begin
        SalesServiceClient.update_opportunity(@opportunity.id, params.require(:opportunity).permit!.to_h.merge(account: params[:account]))
        flash[:notice] = t(:msg_asset_updated, @opportunity.name) rescue nil
      rescue => e
        Rails.logger.error "Sales service update_opportunity failed: #{e.message}"
        @opportunity.errors.add(:base, 'External service error')
      end
      return respond_with(@opportunity)
    end

    respond_with(@opportunity) do |_format|
      if @opportunity.update_with_account_and_permissions(params.permit!)
        if called_from_index_page?
          get_data_for_sidebar
        elsif called_from_landing_page?(:accounts)
          get_data_for_sidebar(:account)
        elsif called_from_landing_page?(:campaigns)
          get_data_for_sidebar(:campaign)
        end
      else
        @accounts = Account.my(current_user).order('name')
        @account = @opportunity.account ? Account.find(@opportunity.account.id) : Account.new(user: current_user)
      end
    end
  end

  # DELETE /opportunities/1
  #----------------------------------------------------------------------------
  def destroy
    if use_sales_service?
      begin
        SalesServiceClient.destroy_opportunity(@opportunity.id)
        flash[:notice] = t(:msg_asset_deleted, @opportunity.name) rescue nil
      rescue => e
        Rails.logger.error "Sales service destroy_opportunity failed: #{e.message}"
        @opportunity.errors.add(:base, 'External service error')
      end
      return respond_with(@opportunity) { |format| format.html { redirect_to opportunities_path } }
    end

    if called_from_landing_page?(:accounts)
      @account = @opportunity.account
    elsif called_from_landing_page?(:campaigns)
      @campaign = @opportunity.campaign
    end
    @opportunity.destroy

    respond_with(@opportunity) do |format|
      format.html { respond_to_destroy(:html) }
      format.js   { respond_to_destroy(:ajax) }
    end
  end

  private

  def order_by_attributes(scope, order)
    scope.weighted_sort.order(order)
  end

  alias get_opportunities get_list_of_records

  def list_includes
    %i[account user tags].freeze
  end

  def load_settings
    @stage = Setting.unroll(:opportunity_stage)
  end

  def set_params
    current_user.pref[:opportunities_per_page] = per_page_param if per_page_param
    current_user.pref[:opportunities_sort_by]  = Opportunity.sort_by_map[params[:sort_by]] if params[:sort_by]
    session[:opportunities_filter] = params[:stage] if params[:stage]
  end

  def use_sales_service?
    ENV['USE_SALES_SERVICE'] == 'true' || params[:use_service] == 'true'
  end
end