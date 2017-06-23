require 'rails_helper'

describe ReviewerReportContext do
  subject(:context) do
    ReviewerReportContext.new(reviewer_report)
  end

  let(:reviewer) { FactoryGirl.create(:user) }
  let(:task) { FactoryGirl.create(:reviewer_report_task, completed: true) }
  let(:reviewer_report) { FactoryGirl.build(:reviewer_report, task: task) }
  let(:reviewer_number) { 33 }
  let(:answer_1) { FactoryGirl.create(:answer) }
  let(:answer_2) { FactoryGirl.create(:answer) }

  context 'rendering a reviewer report' do
    def check_render(template, expected)
      expect(Liquid::Template.parse(template).render(context))
        .to eq(expected)
    end

    before do
      allow(task).to receive(:reviewer_number).and_return reviewer_number
    end

    it 'renders a reviewer' do
      check_render("{{ reviewer.first_name }}", reviewer_report.user.first_name)
    end

    it 'renders a reviewer number' do
      check_render("{{ reviewer_number }}", task.reviewer_number.to_s)
    end

    it 'renders a answers' do
      answers = [answer_1, answer_2]
      reviewer_report.answers = answers
      check_render("{{ answers | size }}", answers.count.to_s)
    end
  end
end
