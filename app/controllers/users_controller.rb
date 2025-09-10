# frozen_string_literal: true

require_relative '../services/user_service_client'
require_relative '../services/user_service_client_with_fallback'


# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class UsersController < ApplicationController
  before_action :set_current_tab, only: %i[show opportunities_overview] # Don't hightlight any tabs.

  check_authorization

  load_and_authorize_resource # handles all security

  respond_to :html, only: %i[show new]

  # GET /users/1
  # GET /users/1.js
  #----------------------------------------------------------------------------
  def show
    @user = current_user if params[:id].nil?

    # Feature flag to gradually migrate
    if use_user_service?
      service_response = user_service.find_user(@user.id)
      if service_response
        @user_data = service_response['data']['attributes']
      end
    end
    respond_with(@user)
  end

  # GET /users/1/edit.js
  #----------------------------------------------------------------------------
  def edit
    respond_with(@user)
  end

  # PUT /users/1
  # PUT /users/1.js
  #----------------------------------------------------------------------------
  def update
    if use_user_service?
      service_response = user_service.update_user(@user.id, user_params)
      if service_response && service_response['data']
        flash[:notice] = t(:msg_user_updated)
        respond_with(@user)
      end
    else
      # Original logic
      @user.update(user_params)
      flash[:notice] = t(:msg_user_updated)
      respond_with(@user)
    end
  end

  # GET /users/1/avatar
  # GET /users/1/avatar.js
  #----------------------------------------------------------------------------
  def avatar
    respond_with(@user)
  end

  # PUT /users/1/upload_avatar
  # PUT /users/1/upload_avatar.js
  #----------------------------------------------------------------------------
  def upload_avatar
    if use_user_service?
      if params[:gravatar]
        user_service.upload_avatar(@user.id, use_gravatar: true)
        render
      else
        if params[:avatar]
          file = params[:avatar][:image] || params[:avatar]
          result = user_service.upload_avatar(@user.id, file: file, use_gravatar: false)
          if result.is_a?(Hash) && result['status'] == 'error'
            @user.avatar ||= Avatar.new
            @user.avatar.errors.clear
            @user.avatar.errors.add(:image, t(:msg_bad_image_file))
          end
        end
        responds_to_parent do
          render
        end
      end
    else
      # Original logic
      if params[:gravatar]
        @user.avatar = nil
        @user.save
        render
      else
        if params[:avatar]
          @avatar = Avatar.create(avatar_params)
          if @avatar.valid?
            @user.avatar = @avatar
          else
            @user.avatar.errors.clear
            @user.avatar.errors.add(:image, t(:msg_bad_image_file))
          end
        end
        responds_to_parent do
          render
        end
      end
    end
  end

  # GET /users/1/password
  # GET /users/1/password.js
  #----------------------------------------------------------------------------
  def password
    respond_with(@user)
  end

  # PUT /users/1/change_password
  # PUT /users/1/change_password.js
  #----------------------------------------------------------------------------
  def change_password
    if use_user_service?
      service_response = user_service.change_password(
        @user.id,
        current_password: params[:current_password],
        password: params.dig(:user, :password),
        password_confirmation: params.dig(:user, :password_confirmation)
      )

      case service_response && service_response['status']
      when 'ok'
        flash[:notice] = t(:msg_password_changed)
      when 'noop'
        flash[:notice] = t(:msg_password_not_changed)
      else
        @user.errors.add(:current_password, t(:msg_invalid_password)) if service_response&.dig('errors', 'current_password')
      end

      respond_with(@user)
    else
      if @user.valid_password?(params[:current_password])
        if params[:user][:password].blank?
          flash[:notice] = t(:msg_password_not_changed)
        else
          @user.password = params[:user][:password]
          @user.password_confirmation = params[:user][:password_confirmation]
          @user.save
          flash[:notice] = t(:msg_password_changed)
        end
      else
        @user.errors.add(:current_password, t(:msg_invalid_password))
      end

      respond_with(@user)
    end
  end

  # GET /users/1/redraw
  #----------------------------------------------------------------------------
  def redraw
    current_user.preference[:locale] = params[:locale]
    render js: %(window.location.href = "#{user_path(current_user)}";)
  end

  # GET /users/opportunities_overview
  #----------------------------------------------------------------------------
  def opportunities_overview
    @users_with_opportunities = User.have_assigned_opportunities.order(:first_name)
    @unassigned_opportunities = Opportunity.my(current_user).unassigned.pipeline.order(:stage).includes(:account, :user, :tags)
  end

  def auto_complete
    if use_user_service?
      query = params[:term] || ''
      results = user_service.auto_complete_users(query)

      respond_to do |format|
        format.json { render json: results }
      end
    else
      # Original logic
      @query = params[:term] || ''
      @users = User.my(current_user).text_search(@query).limit(10).order(:first_name, :last_name)

      respond_to do |format|
        format.json do
          results = @users.map do |a|
            helpers.j(a.full_name + " (@" + a.username + ")")
          end
          render json: results
        end
      end
    end
  end

  private

  # Can use UserServiceClientWithFallback or UserServiceClient directly
  def user_service
    @user_service ||= UserServiceClientWithFallback.new
  end

  def use_user_service?
    # Feature flag - start with false, gradually enable
    ENV['USE_USER_SERVICE'] == 'true' || params[:use_service] == 'true'
  end

  protected

  def user_params
    return {} unless params[:user]

    params[:user][:email].try(:strip!)
    params[:user][:alt_email].try(:strip!)

    params[:user].permit(
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
      :skype
    )
  end

  def avatar_params
    return {} unless params[:avatar]

    params[:avatar]
      .permit(:image)
      .merge(entity: @user, user_id: @user.id)
  end

  ActiveSupport.run_load_hooks(:fat_free_crm_users_controller, self)
end