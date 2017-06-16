require 'rails_helper'

feature "User adding reviewer candidates", js: true do
  let(:admin) { create :user, :site_admin, first_name: 'Admin' }
  let!(:paper) do
    create :paper,:with_integration_journal, :with_tasks, creator: admin
  end
  let!(:reviewer_recommendations_task) do
    FactoryGirl.create(
      :reviewer_recommendations_task,
      paper: paper,
      phase: paper.phases.first
    )
  end

  before do
    login_as(admin, scope: :user)
    Page.view_paper_workflow paper
  end

  scenario "A user can add reviewer candidates" do
    page = Page.new
    page.view_card("Reviewer Candidates")

    # Bringing up the new reviewer candidate form
    click_button "New Reviewer Candidate"
    expect(page).to have_selector(".reviewer-form")

    # Clicking cancel hides the new reviewer form
    within ".reviewer-form" do
      find("a", text: "cancel").click
    end
    expect(page).to_not have_selector(".reviewer-form")

    click_button "New Reviewer Candidate"
    expect(page).to have_selector(".reviewer-form")

    # Add a new reviewer
    within ".reviewer-form" do
      find(".first-name input[type=text]").set "Barb"
      find(".last-name input[type=text]").set "AraAnn"
      find(".email input[type=text]").set "barb@example.com"
      choose "Recommend"
      find("textarea[name*=reason]").set "Because they do good work"
      click_button "done"
    end

    # See the new reviewer
    within ".reviewer" do
      expect(page).to have_selector(".full-name", text: "Barb AraAnn")
      expect(page).to have_selector(".email", text: "barb@example.com")
      expect(page).to have_selector(".reason", text: "Because they do good work")
    end

    # Edit the reviewer
    find(".qa-edit-reviewer-form").click

    # We can cancel the edit
    within ".reviewer-form" do
      find(".reviewer-form a.cancel").click
    end
    expect(page).to_not have_selector(".reviewer-form")

    # We can edit the reviewer
    find(".qa-edit-reviewer-form").click
    within ".reviewer-form" do
      first_name_input = find(".first-name input[type=text]")
      expect(first_name_input.value).to eq("Barb")

      find(".first-name input[type=text]").set "Bob"
      click_button "done"
    end

    # See updated reviewer
    within ".reviewer" do
      expect(page).to have_selector(".full-name", text: "Bob AraAnn")
    end
  end

end
