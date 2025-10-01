class Admin::UsersController < Admin::ApplicationController
  before_action :setup_current_tab, only: %i[index show]

  load_resource except: [:create]

  # GET /admin/users
  # GET /admin/users.xml                                                   HTML
  #----------------------------------------------------------------------------
  def index
    if use_admin_service?
      begin
        # You can extend params forwarding as needed (q/query/page/per_page)
        service_resp = AdminServiceClient.list_users(page: params[:page], per_page: params[:per_page], q: params[:q], query: params[:query])
        # Render as usual; keep @users as AR relation for views when flag is off.
        # For demo: keep local query since views expect AR. Optionally set a presenter:
        @service_users = service_resp && service_resp['data'] || service_resp&.dig(:data)
      rescue => e
        Rails.logger.error "Admin service list_users failed: #{e.message}"
      end
    end
    @users = get_users(page: params[:page])
    respond_with(@users)
  end

  # GET /admin/users/1
  # GET /admin/users/1.xml
  #----------------------------------------------------------------------------
  def show
    if use_admin_service?
      begin
        @service_user = AdminServiceClient.get_user(params[:id])
      rescue => e
        Rails.logger.error "Admin service get_user failed: #{e.message}"
      end
    end
    respond_with(@user)
  end

  # GET /admin/users/new
  # GET /admin/users/new.xml                                               AJAX
  #----------------------------------------------------------------------------
  def new
    respond_with(@user)
  end

  # GET /admin/users/1/edit                                                AJAX
  #----------------------------------------------------------------------------
  def edit
    @previous = User.find_by_id(detect_previous_id) || detect_previous_id if detect_previous_id

    if use_admin_service?
      begin
        @service_user = AdminServiceClient.get_user(@user.id)
      rescue => e
        Rails.logger.error "Admin service get_user (edit) failed: #{e.message}"
      end
    end

    respond_with(@user)
  end

  # POST /admin/users
  # POST /admin/users.xml                                                  AJAX
  #----------------------------------------------------------------------------
  def create
    if use_admin_service?
      begin
        AdminServiceClient.create_user(user_params.to_h)
        flash[:notice] = t(:msg_user_created) rescue nil
      rescue => e
        Rails.logger.error "Admin service create_user failed: #{e.message}"
        @user = User.new(user_params) # for form re-rendering
        @user.errors.add(:base, 'External service error')
      end
      return respond_with(@user)
    end

    @user = User.new(user_params)
    @user.suspend_if_needs_approval
    @user.save
    respond_with(@user)
  end

  # PUT /admin/users/1
  # PUT /admin/users/1.xml                                                 AJAX
  #----------------------------------------------------------------------------
  def update
    if use_admin_service?
      begin
        AdminServiceClient.update_user(params[:id], user_params.to_h)
        flash[:notice] = t(:msg_user_updated)
      rescue => e
        Rails.logger.error "Admin service update_user failed: #{e.message}"
        @user = User.find(params[:id]) rescue User.new
        @user.errors.add(:base, 'External service error')
      end
      return respond_with(@user)
    end

    @user = User.find(params[:id])
    @user.attributes = user_params
    @user.save
    respond_with(@user)
  end

  # GET /admin/users/1/confirm                                             AJAX
  #----------------------------------------------------------------------------
  def confirm
    if use_admin_service?
      begin
        @service_user = AdminServiceClient.get_user(@user.id)
      rescue => e
        Rails.logger.error "Admin service get_user (confirm) failed: #{e.message}"
      end
    end
    respond_with(@user)
  end

  # DELETE /admin/users/1
  # DELETE /admin/users/1.xml                                              AJAX
  #----------------------------------------------------------------------------
  def destroy
    if use_admin_service?
      begin
        AdminServiceClient.destroy_user(@user.id)
        flash[:notice] = t(:msg_asset_deleted, @user.full_name) rescue nil
      rescue => e
        Rails.logger.error "Admin service destroy_user failed: #{e.message}"
        @user.errors.add(:base, 'External service error')
      end
      return respond_with(@user)
    end

    flash[:warning] = t(:msg_cant_delete_user, @user.full_name) unless @user.destroyable?(current_user) && @user.destroy
    respond_with(@user)
  end

  # PUT /admin/users/1/suspend
  # PUT /admin/users/1/suspend.xml                                         AJAX
  #----------------------------------------------------------------------------
  def suspend
    if use_admin_service?
      begin
        AdminServiceClient.suspend_user(@user.id) if @user != current_user
        flash[:notice] = t(:msg_user_suspended) rescue nil
      rescue => e
        Rails.logger.error "Admin service suspend_user failed: #{e.message}"
        @user.errors.add(:base, 'External service error')
      end
      return respond_with(@user)
    end

    if @user != current_user
      @user.update_attribute(:suspended_at, Time.now)
    end
    respond_with(@user)
  end

  # PUT /admin/users/1/reactivate
  # PUT /admin/users/1/reactivate.xml                                      AJAX
  #----------------------------------------------------------------------------
  def reactivate
    if use_admin_service?
      begin
        AdminServiceClient.reactivate_user(@user.id)
        flash[:notice] = t(:msg_user_reactivated) rescue nil
      rescue => e
        Rails.logger.error "Admin service reactivate_user failed: #{e.message}"
        @user.errors.add(:base, 'External service error')
      end
      return respond_with(@user)
    end

    @user.update_attribute(:suspended_at, nil)
    respond_with(@user)
  end

  protected

  def user_params
    return {} unless params[:user]

    params[:user][:password_confirmation] = nil if params[:user][:password_confirmation].blank?
    params[:user][:email].try(:strip!)
    params[:user][:alt_email].try(:strip!)

    params[:user].permit(
      :admin,
      :username,
      :email,
      :first_name,
      :last_name,
      :title,
      :company,
      :alt_email,
      :phone,
      :mobile,
      :aim,
      :yahoo,
      :google,
      :skype,
      :password,
      :password_confirmation,
      group_ids: []
    )
  end

  private

  def get_users(options = {})
    self.current_page  = options[:page] if options[:page]
    self.current_query = params[:query] if params[:query]

    @search = klass.ransack(params[:q])
    @search.build_grouping unless @search.groupings.any?

    wants = request.format
    scope = User.by_id
    scope = scope.merge(@search.result)
    scope = scope.text_search(current_query)      if current_query.present?
    scope = scope.paginate(page: current_page) if wants.html? || wants.js? || wants.xml?
    scope
  end

  def setup_current_tab
    set_current_tab('admin/users')
  end

  def admin_service
    AdminServiceClient
  end

  def use_admin_service?
    ENV['USE_ADMIN_SERVICE'] == 'true' || params[:use_service] == 'true'
  end
end