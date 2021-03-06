# Copyright (c) 2018 Public Library of Science

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

require 'rails_helper'
require 'support/pages/overlays/changes_for_author_overlay'
require 'support/pages/overlays/revision_tech_check_overlay'
require 'support/rich_text_editor_helpers'

include RichTextEditorHelpers

feature 'Revision Tech Check', js: true do
  let(:journal) { create :journal, :with_roles_and_permissions }
  let(:editor) { create :user }
  let(:author) { create :user }
  let(:paper) { create :paper, :submitted, journal: journal, creator: author }
  let(:task) { create :revision_tech_check_task, :with_loaded_card, paper: paper }
  let(:words) { %w(Data Availability Financial Competing Figure Ethics) }

  before do
    assign_journal_role journal, editor, :editor
  end

  scenario 'Revision Tech Check triggers Changes For Author' do
    # Editor
    login_as(editor, scope: :user)
    overlay = Page.view_task_overlay(paper, task)
    expect(PlosBioTechCheck::ChangesForAuthorTask.count).to eq(0)
    overlay.create_author_changes_card
    overlay.expect_author_changes_saved
    overlay.mark_as_complete
    overlay.dismiss
    logout

    change_author_task = PlosBioTechCheck::ChangesForAuthorTask.first

    # Author
    login_as(author, scope: :user)
    overlay = Page.view_task_overlay(paper, change_author_task)
    overlay.expect_to_see_change_list
    overlay.mark_as_complete
    overlay.dismiss

    # creator cannot access revision tech check task
    Page.view_task task
    expect(page).to have_content("You don't have access to that content")
  end

  scenario "list the unselected question items in the author changes letter" do
    login_as(editor, scope: :user)
    overlay = Page.view_task_overlay(paper, task)
    overlay.display_letter
    overlay.click_autogenerate_email_button
    text = overlay.letter_text
    expect(text).to include(*words)

    question_elements = all(".question-checkbox")
    first_question = question_elements.first
    last_question = question_elements.last
    first_question.find("input").click
    last_question.find("input").click

    text = overlay.letter_text
    expect(text).to_not include first_question.find(".model-question").text
    expect(text).to_not include last_question.find(".model-question").text
  end

  scenario "selected questions don't show up in the auto-generated author change letter" do
    login_as(editor, scope: :user)
    overlay = Page.view_task_overlay(paper, task)
    overlay.display_letter
    overlay.click_autogenerate_email_button
    text = overlay.letter_text
    expect(text).to include(*words)

    question_elements = all(".question-checkbox")
    first_question = question_elements.first
    first_question.find("input").click
    overlay.click_autogenerate_email_button

    text = overlay.letter_text
    expect(text).to_not include('Data, Availability, Financial, Competing, Figure, Ethics')
  end

  scenario "unchecking a box with no associated text has no effect" do
    login_as(editor, scope: :user)
    overlay = Page.view_task_overlay(paper, task)
    overlay.display_letter
    overlay.click_autogenerate_email_button
    text_before = overlay.letter_text

    question_elements = all(".question-checkbox")
    question = question_elements[1]
    question.find("input").click
    overlay.click_autogenerate_email_button

    text_after = overlay.letter_text
    expect(text_before).to eq(text_after)
  end
end
