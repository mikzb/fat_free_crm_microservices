class ContactsController < EntitiesController
  # GET /contacts
  #----------------------------------------------------------------------------
  def index
    if use_sales_service?
      begin
        resp = SalesServiceClient.list_contacts(page: page_param, per_page: per_page_param, query: params[:query], q: params[:q])
        @service_contacts = resp && (resp['data'] || resp[:data])
      rescue => e
        Rails.logger.error "Sales service list_contacts failed: #{e.message}"
      end
    end
    @contacts = get_contacts(page: page_param, per_page: per_page_param)
    respond_with(@contacts)
  end

  # GET /contacts/1
  #----------------------------------------------------------------------------
  def show
    if use_sales_service?
      begin
        @service_contact = SalesServiceClient.get_contact(@contact.id)
      rescue => e
        Rails.logger.error "Sales service get_contact failed: #{e.message}"
      end
    end
    respond_with(@contact)
  end

  # POST /contacts
  #----------------------------------------------------------------------------
  def create
    if use_sales_service?
      begin
        SalesServiceClient.create_contact(resource_params.to_h)
        flash[:notice] = t(:msg_asset_created, @contact.full_name) rescue nil
      rescue => e
        Rails.logger.error "Sales service create_contact failed: #{e.message}"
        @contact.errors.add(:base, 'External service error')
      end
      return respond_with(@contact)
    end

    @comment_body = params[:comment_body]
    if @contact.save_with_account_and_permissions(params.permit!)
      @contact.add_comment_by_user(@comment_body, current_user)
    end
    respond_with(@contact)
  end

  # PUT /contacts/1
  #----------------------------------------------------------------------------
  def update
    if use_sales_service?
      begin
        SalesServiceClient.update_contact(@contact.id, resource_params.to_h)
        flash[:notice] = t(:msg_asset_updated, @contact.full_name) rescue nil
      rescue => e
        Rails.logger.error "Sales service update_contact failed: #{e.message}"
        @contact.errors.add(:base, 'External service error')
      end
      return respond_with(@contact)
    end

    if @contact.update_with_account_and_permissions(params.permit!)
      # nothing extra
    end
    respond_with(@contact)
  end

  # DELETE /contacts/1
  #----------------------------------------------------------------------------
  def destroy
    if use_sales_service?
      begin
        SalesServiceClient.destroy_contact(@contact.id)
        flash[:notice] = t(:msg_asset_deleted, @contact.full_name) rescue nil
      rescue => e
        Rails.logger.error "Sales service destroy_contact failed: #{e.message}"
        @contact.errors.add(:base, 'External service error')
      end
      return respond_with(@contact) { |format| format.html { redirect_to contacts_path } }
    end

    @contact.destroy
    respond_with(@contact)
  end

  private

  alias get_contacts get_list_of_records

  def use_sales_service?
    ENV['USE_SALES_SERVICE'] == 'true' || params[:use_service] == 'true'
  end
end