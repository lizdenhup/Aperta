require 'rails_helper'

feature 'Comments on cards', js: true do
  let(:admin) { create :user, :site_admin, first_name: "Admin" }
  let(:albert) { create :user, first_name: "Albert" }
  let!(:paper) { FactoryGirl.create(:paper_with_phases, creator: admin, submitted: true) }

  before do
    sign_in_page = SignInPage.visit
    sign_in_page.sign_in admin
  end

  describe "commenting" do
    let!(:task) { create :task, phase: paper.phases.first }

    before do
      click_link paper.title
      within ".control-bar" do
        click_link "Workflow"
      end
    end

    # TODO: FAILING - participant is being added as an after effect and socket is being ignored
    scenario "becoming a participant" do
      task_manager_page = TaskManagerPage.new
      task_manager_page.view_card task.title, CardOverlay do |card|
        card.post_message 'Hello'
        expect(card).to have_participants(admin)
        expect(card).to have_last_comment_posted_by(admin)
      end
    end
  end

  describe "being made aware of commenting" do
    let!(:task) { create :task, phase: paper.phases.first, participants: [admin, albert] }

    before do
      task.comments.create(commenter: albert, body: 'test')
      CommentLookManager.sync_task(task)
      click_link paper.title
      within ".control-bar" do
        click_link "Workflow"
      end
    end

    scenario "displays the number of unread comments as badge on task" do
      page = TaskManagerPage.new
      expect(page.tasks.first.unread_comments_badge).to eq(1)
    end
  end
end
