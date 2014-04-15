class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :verify_admin!, except: [:show, :update, :update_participants]
  respond_to :json

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  def update
    task = if current_user.admin?
             Task.where(id: params[:id]).first
           else
             current_user.tasks.where(id: params[:id]).first
           end

    tp = task_params(task)

    tp = munge_empty_arrays(tp)

    if task && task.authorize_update!(tp, current_user)
      task.update! tp
      task.reload
      ts = task.active_model_serializer.new(task, root: :task)
      EventStream.post_event(task.paper.id, ts.as_json.merge({type: ts.type}).to_json)

      render task.update_responder.new(task, view_context).response
    else
      head :forbidden
    end
  end

  def create
    task = build_task
    if task.persisted?
      respond_with task, location: task_url(task)
    else
      render status: 500
    end
  end

  def show
    @task = Task.find(params[:id])
    respond_to do |f|
      f.json { render json: @task }
      f.html { render 'ember/index' , layout: 'ember'}
    end
  end

  def destroy
    task_temp = Task.find(params[:id])
    task = PaperPolicy.new(task_temp.paper, current_user).tasks_for_paper(params[:id]).first
    if task && task.destroy
      render json: true
    else
      render status: 400
    end
  end

  private

  def task_params(task = nil)
    attributes = [:assignee_id, :completed, :title, :body, :phase_id]
    attributes += task.class::PERMITTED_ATTRIBUTES if task
    params.require(:task).permit(*attributes)
  end

  def build_task
    task_type = params[:task][:type]
    sanitized_params = task_params task_type.constantize.new
    TaskFactory.build_task task_type, sanitized_params, current_user
  end

  def munge_empty_arrays(task_params)
    permitted_empty_arrays.each do |key|
      if params[:task].has_key?(key) && params[:task][key].nil?
        task_params[key.to_s] = []
      end
    end
    task_params
  end

  def permitted_empty_arrays
    [:reviewer_ids]
  end

  def render_404
    head 404
  end
end
