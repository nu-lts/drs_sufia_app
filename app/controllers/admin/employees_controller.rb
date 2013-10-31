class Admin::EmployeesController < ApplicationController

  before_filter :authenticate_user! 
  before_filter :verify_admin
  before_filter :load_employee, except: [:index] 

  def index 
    @employees = Employee.all
  end

  def edit 

  end

  def update 

    if params[:remove].present? 
      @employee.remove_community(Community.find(params[:remove]))
      @employee.save! 
    else
      @employee.add_community(Community.find(params[:admin][:community]))
      @employee.save!
    end

    respond_to do |format| 
      format.js
    end
  end

  def destroy 

  end

  private 

    def load_employee
      @employee = Employee.find(params[:id]) 
    end

    def verify_admin 
      redirect_to root_path unless current_user.admin? 
    end
end