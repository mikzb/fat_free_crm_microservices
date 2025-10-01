class Admin::GroupsController < Admin::ApplicationController
  before_action :setup_current_tab, only: %i[index show]

  load_resource

  # GET /groups
  #----------------------------------------------------------------------------
  def index
    if use_admin_service?
      begin
        service_resp = AdminServiceClient.list_groups(page: params[:page], per_page: params[:per_page])
        @service_groups = service_resp && service_resp['data'] || service_resp&.dig(:data)
      rescue => e
        Rails.logger.error "Admin service list_groups failed: #{e.message}"
      end
    end
    @groups = @groups.unscoped.paginate(page: params[:page])
  end

  # GET /groups/1
  #----------------------------------------------------------------------------
  def show
    if use_admin_service?
      begin
        @service_group = AdminServiceClient.get_group(@group.id)
      rescue => e
        Rails.logger.error "Admin service get_group failed: #{e.message}"
      end
    end
    respond_with(@group)
  end

  # GET /groups/new
  #----------------------------------------------------------------------------
  def new
    respond_with(@group)
  end

  # GET /groups/1/edit
  #----------------------------------------------------------------------------
  def edit
    if use_admin_service?
      begin
        @service_group = AdminServiceClient.get_group(@group.id)
      rescue => e
        Rails.logger.error "Admin service get_group (edit) failed: #{e.message}"
      end
    end
    respond_with(@group)
  end

  # POST /groups
  #----------------------------------------------------------------------------
  def create
    if use_admin_service?
      begin
        AdminServiceClient.create_group(group_params.to_h)
        flash[:notice] = t(:msg_asset_created, t(:group)) rescue nil
      rescue => e
        Rails.logger.error "Admin service create_group failed: #{e.message}"
        @group.errors.add(:base, 'External service error')
      end
      return respond_with(@group)
    end

    @group.attributes = group_params
    @group.save
    respond_with(@group)
  end

  # PUT /groups/1
  #----------------------------------------------------------------------------
  def update
    if use_admin_service?
      begin
        AdminServiceClient.update_group(@group.id, group_params.to_h)
        flash[:notice] = t(:msg_asset_updated, t(:group)) rescue nil
      rescue => e
        Rails.logger.error "Admin service update_group failed: #{e.message}"
        @group.errors.add(:base, 'External service error')
      end
      return respond_with(@group)
    end

    @group.update(group_params)
    respond_with(@group)
  end

  # DELETE /groups/1
  #----------------------------------------------------------------------------
  def destroy
    if use_admin_service?
      begin
        AdminServiceClient.destroy_group(@group.id)
        flash[:notice] = t(:msg_asset_deleted, t(:group)) rescue nil
      rescue => e
        Rails.logger.error "Admin service destroy_group failed: #{e.message}"
        @group.errors.add(:base, 'External service error')
      end
      return respond_with(@group)
    end

    @group.destroy
    respond_with(@group)
  end

  protected

  def group_params
    params.require(:group).permit(:name, user_ids: [])
  end

  def setup_current_tab
    set_current_tab('admin/groups')
  end

  private

  def use_admin_service?
    ENV['USE_ADMIN_SERVICE'] == 'true' || params[:use_service] == 'true'
  end
end