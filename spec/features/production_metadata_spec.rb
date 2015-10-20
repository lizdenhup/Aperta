require 'rails_helper'

feature 'Production Metadata Card', js: true do
  let(:admin) { create :user, site_admin: true, first_name: 'Admin' }
  let(:author) { create :user, first_name: 'Author' }
  let!(:paper)  { create :paper, :with_tasks, creator: author }
  let(:production_metadata_task) do
    create :production_metadata_task, phase: paper.phases.first
  end

  before do
    login_as admin
    visit "/papers/#{paper.id}/tasks/#{production_metadata_task.id}"
  end

  describe 'completing a Production Metadata card' do
    describe 'adding a volumne number' do
      it 'does not allows alphas to be entered' do
        fill_in('volume_number', with: 'alpha characters')
        volume_number_input = page.first('input[name=volume_number]')
        expect(volume_number_input.value).not_to eq 'alpha characters'
      end

      it 'allows numbers to be entered' do
        fill_in('volume_number', with: 1234)
        volume_number_input = page.first('input[name=volume_number]')
        expect(volume_number_input.value).to eq '1234'
      end
    end

    describe 'adding an issue number' do
      it 'does not allows alphas to be entered' do
        fill_in('issue_number', with: 'alpha characters')
        issue_number_input = page.first('input[name=issue_number]')
        expect(issue_number_input.value).not_to eq 'alpha characters'
      end

      it 'allows numbers to be entered' do
        fill_in('issue_number', with: 1234)
        issue_number_input = page.first('input[name=issue_number]')
        expect(issue_number_input.value).to eq '1234'
      end
    end

    describe 'filling in the entire card' do
      it 'persists information' do
        page.fill_in 'publication_date', with: '08/31/2015'
        page.execute_script "$(\"input[name='publication_date']\").trigger('change')"
        page.fill_in 'volume_number', with: '1234'
        page.execute_script "$(\"input[name='volume_number']\").trigger('change')"
        page.fill_in 'issue_number', with: '5678'
        page.execute_script "$(\"input[name='issue_number']\").trigger('change')"
        page.fill_in 'production_notes', with: 'Too cool for school.'
        page.execute_script "$(\"textarea[name='production_notes']\").trigger('change')"
        wait_for_ajax

        visit "/papers/#{paper.id}/tasks/#{production_metadata_task.id}"

        find('h1', text: 'Production Metadata')
        within '.overlay-main-work' do
          expect(page).to have_field('volume_number', with: "1234")
          expect(page).to have_field('issue_number', with: "5678")
          expect(page).to have_field('production_notes', with: "Too cool for school.")
          expect(page).to have_field('publication_date', with: "08/31/2015")
        end
      end
    end

    context 'clicking complete' do
       describe 'with invalid input in required fields' do
        it 'shows an error'do
          find('#task_completed').click
          expect(find(".publication-date")).to have_text("Can't be blank")
          expect(find(".volume-number")).to have_text("Must be a whole number")
          expect(find(".issue-number")).to have_text("Must be a whole number")
        end
      end
    end
  end
end