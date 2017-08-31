class FeedbackController < ApplicationController
  before_action :authenticate_user!

  def create
    FeedbackMailer.contact(current_user, feedback_params).deliver_later
    JIRAIntegrationService.instance.create_issue(current_user, feedback_params)
    render json: {}, status: :created
  end

  private

  def feedback_params
    params.require(:feedback).permit(:remarks, :referrer, screenshots: [:url, :filename])
  end
end
