require 'rails_helper'

feature 'Reviewer filling out their research article reviewer report', js: true do
  let(:journal) { FactoryGirl.create :journal, :with_roles_and_permissions }
  let(:paper) do
    FactoryGirl.create \
      :paper_with_phases,
      :submitted_lite,
      :with_creator,
      journal: journal,
      uses_research_article_reviewer_report: true
  end
  let(:task) { FactoryGirl.create :paper_reviewer_task, paper: paper }

  let(:paper_page){ PaperPage.new }
  let!(:reviewer) { create :user }
  let!(:reviewer_report_task) do
    create_reviewer_report_task
  end

  def create_reviewer_report_task
    ReviewerReportTaskCreator.new(
      originating_task: task,
      assignee_id: reviewer.id
    ).process
  end

  before do
    assign_reviewer_role paper, reviewer

    login_as(reviewer, scope: :user)
    visit "/"
    Page.view_paper paper
  end

  scenario "A paper's creator cannot access the Reviewer Report" do
    ensure_user_does_not_have_access_to_task(
      user: paper.creator,
      task: reviewer_report_task
    )
  end

  scenario 'A reviewer can fill out their own Reviewer Report, submit it, and see a readonly view of their responses' do
    t = paper_page.view_task("Review by #{reviewer.full_name}", ReviewerReportTaskOverlay)
    t.fill_in_report 'reviewer_report--competing_interests--detail' =>
      'I have no competing interests'
    t.submit_report
    t.confirm_submit_report

    expect(page).to have_selector('.answer-text',
                                  text: 'I have no competing interests')
  end

  scenario 'A review can see their previous rounds of review' do
    # Revision 0
    Page.view_paper paper

    t = paper_page.view_task("Review by #{reviewer.full_name}", ReviewerReportTaskOverlay)
    t.fill_in_report 'reviewer_report--competing_interests--detail' =>
      'answer for round 0'

    # no history yet, since we only have the current round of review
    t.ensure_no_review_history

    t.submit_report
    t.confirm_submit_report

    # Revision 1
    register_paper_decision(paper, "major_revision")
    paper.submit! paper.creator
    create_reviewer_report_task

    Page.view_paper paper
    t = paper_page.view_task("Review by #{reviewer.full_name}",
                             ReviewerReportTaskOverlay)

    t.fill_in_report 'reviewer_report--competing_interests--detail' =>
      'answer for round 1'

    t.ensure_review_history(
      title: 'Revision 0', answers: ['answer for round 0']
    )

    t.submit_report
    t.confirm_submit_report

    # Revision 2
    register_paper_decision(paper, "major_revision")
    paper.submit! paper.creator

    Page.view_paper paper
    # For some reason the task must be reloaded here for it to register
    create_reviewer_report_task
    t = paper_page.view_task("Review by #{reviewer.full_name}", ReviewerReportTaskOverlay)
    t.fill_in_report 'reviewer_report--competing_interests--detail' =>
      'answer for round 2'

    t.ensure_review_history(
      {title: 'Revision 0', answers: ['answer for round 0']},
      {title: 'Revision 1', answers: ['answer for round 1']}
    )

    # Revision 3 (we won't answer, just look at previous rounds)
    register_paper_decision(paper, "major_revision")
    paper.submit! paper.creator
    create_reviewer_report_task

    Page.view_paper paper
    t = paper_page.view_task("Review by #{reviewer.full_name}", ReviewerReportTaskOverlay)

    t.ensure_review_history(
      {title: 'Revision 0', answers: ['answer for round 0']},
      {title: 'Revision 1', answers: ['answer for round 1']},
      {title: 'Revision 2', answers: ['answer for round 2']}
    )
  end
end
