module PlosBioTechCheck
  class InitialTechCheckController < ApplicationController
    before_action :authenticate_user!

    def send_email
      requires_user_can :edit, task
      task.notify_author_of_changes!(submitted_by: current_user)
      render json: { success: true }
    end

    private

    def task
      @task ||= InitialTechCheckTask.find(params[:id])
    end
  end
end
