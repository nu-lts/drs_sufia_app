class Admin::UsersController < AdminController

  before_filter :authenticate_user!
  before_filter :verify_admin

  def index
    get_users(params)
    respond_to do |format|
      format.html
      format.js
    end
  end

  def impersonate_user
    user = User.find(params[:id])
    if !user.admin?
      session[:impersonate] = "Warning! You are currently logged in as another user. Beware that all your actions will be done as them."
      sign_in user, :event => :authentication
      redirect_to root_path
    else
      # raise error and email developers
    end
  end

  def get_users(params)
    if params[:search]
      @users = User.where('full_name LIKE ?', "%#{params[:search]}%").order(:full_name).paginate(:page => params[:page], :per_page => 10)
    else
      @users = User.order(:full_name).paginate(:page => params[:page], :per_page => 10)
    end
    return @users
  end
end