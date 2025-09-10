# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

RSpec.describe UsersController, type: :controller do
  let(:user) { create(:user) }

  before do
    sign_in user
    allow_any_instance_of(UsersController).to receive(:use_user_service?).and_return(true)
  end

  describe 'PUT update via service' do
    let(:service) { instance_double(UserServiceClientWithFallback) }

    before do
      allow_any_instance_of(UsersController).to receive(:user_service).and_return(service)
      allow(service).to receive(:update_user).and_return(
        'data' => { 'id' => user.id.to_s, 'attributes' => user.attributes }
      )
      @request.env['HTTP_ACCEPT'] = 'text/javascript'
      @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
    end

    it 'sets flash and responds' do
      put :update, params: { id: user.id, user: { first_name: 'New' } }, format: :js
      expect(flash[:notice]).to be_present
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH change_password via service' do
    let(:service) { instance_double(UserServiceClientWithFallback) }

    before do
      allow_any_instance_of(UsersController).to receive(:user_service).and_return(service)
      @request.env['HTTP_ACCEPT'] = 'text/javascript'
      @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
    end

    it 'shows success notice when service returns ok' do
      allow(service).to receive(:change_password).and_return('status' => 'ok', 'message' => 'changed')
      patch :change_password, params: { id: user.id, current_password: 'old', user: { password: 'new', password_confirmation: 'new' } }, format: :js
      expect(flash[:notice]).to be_present
      expect(response).to have_http_status(:ok)
    end

    it 'shows noop notice when service returns noop' do
      allow(service).to receive(:change_password).and_return('status' => 'noop', 'message' => 'not changed')
      patch :change_password, params: { id: user.id, current_password: 'old', user: { password: '', password_confirmation: '' } }, format: :js
      expect(flash[:notice]).to be_present
      expect(response).to have_http_status(:ok)
    end

    it 'adds error when service returns error' do
      allow(service).to receive(:change_password).and_return('status' => 'error', 'errors' => { 'current_password' => ['invalid'] })
      patch :change_password, params: { id: user.id, current_password: 'WRONG', user: { password: 'new', password_confirmation: 'new' } }, format: :js
      expect(assigns(:user).errors[:current_password]).to be_present
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PUT upload_avatar via service' do
    let(:service) { instance_double(UserServiceClientWithFallback) }

    before do
      allow_any_instance_of(UsersController).to receive(:user_service).and_return(service)
    end

    it 'toggles gravatar' do
      allow(service).to receive(:upload_avatar).with(user.id, use_gravatar: true).and_return('status' => 'ok')
      put :upload_avatar, params: { id: user.id, gravatar: true }
      expect(response).to have_http_status(:ok)
    end

    it 'uploads file and renders via responds_to_parent' do
      file = fixture_file_upload('rails.png', 'image/png')
      allow(service).to receive(:upload_avatar).and_return('status' => 'ok')

      put :upload_avatar, params: { id: user.id, avatar: { image: file } }
      expect(response).to have_http_status(:ok)
    end

    it 'handles bad file error from service' do
      file = fixture_file_upload('bad.txt', 'text/plain')
      allow(service).to receive(:upload_avatar).and_return('status' => 'error', 'errors' => { 'image' => ['Invalid'] })

      put :upload_avatar, params: { id: user.id, avatar: { image: file } }
      expect(assigns(:user).avatar.errors[:image]).to be_present
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET auto_complete via service' do
    let(:service) { instance_double(UserServiceClientWithFallback) }

    before do
      allow_any_instance_of(UsersController).to receive(:user_service).and_return(service)
    end

    it 'renders json results' do
      results = ['Alice (@alice)', 'Bob (@bob)']
      allow(service).to receive(:auto_complete_users).with('al').and_return(results)

      # Debug: see what service is actually called with
      puts "Service mock set up for: 'al'"
      get :auto_complete, params: { term: 'al' }, format: :json

      puts "Response body: #{response.body}"
      puts "Response status: #{response.status}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(results)
    end
  end
end