class UserController < ApplicationController
  skip_before_filter :verify_authenticity_token, only: :verify_user  

  def create_token
    t = UserToken.new
    if t.save
      render json: {"user_token" => t.token}, callback: params['callback']
    else
      render json: {"error"=> "could not generate user_token"}, status: 500, callback: params['callback']
    end
  end

  def verify_user
    service = Service.find_by_id(params[:service_id])
    site = Site.find_by_token(params[:site_token])
    old_user_token = UserToken.find_by_token(params[:user_token])
    unless service.nil? or site.nil? or old_user_token.nil?
      account = service.accounts.find_by_service_user_identifier(params[:service_user_id])
      if account.nil?
        account = Account.new
        account.service = service
        account.service_user_identifier = params[:service_user_id]

        #TODO if the UserToken is already associated with a user - do we join it to that user? doing that for now
        if old_user_token.user.nil?
          old_user_token.user = User.new
          old_user_token.user.display_name = params[:display_name]
          old_user_token.avatar_url = params[:avatar_url]
          old_user_token.save
        end
        account.user = old_user_token.user
        account.save
        render json: {"user_token" => old_user_token.token}, status: 200
      else
        old_user_token.user = account.user
        old_user_token.save
        render json: {"user_token" => old_user_token.token}, status: 200
      end
    else
      render json: {"error"=> "incorrect tokens"}, status: 400
    end
  end

  def ban
    token = UserToken.find_by_token(params[:user_token])
    token.banned = true
    token.save
    puts "token banned"
    if token.user
      token.user.banned = true
      token.user.user_tokens.each do |ut|
        ut.banned = true
        ut.save
      end
      token.user.save
    end
    redirect_to users_path
  end

  def unban
    token = UserToken.find_by_token(params[:user_token])
    token.banned = false
    token.save
    if token.user
      token.user.banned = false
      token.user.user_tokens.each do |ut|
        ut.banned = false
        ut.save
      end
      token.user.save
    end
    redirect_to users_path
  end

  def index
    @all_registered = User.all
    @all_anon = UserToken.where(user_id: nil)
    case params[:filter]
    when "registered_only"
      @registered_users = User.all
      @anon_users = UserToken.none
    when "anon_only"
      @registered_users = User.none
      @anon_users = UserToken.where(user_id: nil)
    when "moderators"
      @registered_users = User.moderators
      @anon_users = UserToken.none
    when "need_moderation"
      @registered_users = User.needs_attention
      @anon_users = UserToken.where(user_id:nil).needs_attention
    when "banned"
      @registered_users = User.banned
      @anon_users = UserToken.where(user_id:nil).banned
    else
      @registered_users = User.all
      @anon_users = UserToken.where(user_id: nil)
    end
  end
  
end
