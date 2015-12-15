require 'rails_helper'

feature 'Viewing manuscript control bar', js: true do
  before do
    login_as(user, scope: :user)
    visit "/papers/#{paper.id}"
  end

  context 'as an admin' do
    let(:user) { FactoryGirl.create :user, :site_admin }
    let(:paper) { FactoryGirl.create :paper }

    scenario 'can view the Go to Workflow link' do
      expect(page).to have_css('#go-to-workflow')
    end
  end

  context 'as an author' do
    let(:user) { FactoryGirl.create :user }
    let(:paper) { FactoryGirl.create :paper, creator: user }

    scenario 'can not view the Go to Workflow link' do
      expect(page).to_not have_css('#go-to-workflow')
    end
  end
end