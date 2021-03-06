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
require 'support/authorization_spec_helper'

describe <<-DESC.strip_heredoc do
  In order to be able to communicate permission information to the front-end
  application the authorizations sub-system provides access to a
  stable Hash data format.
DESC
  include AuthorizationSpecHelper

  before(:all) do
    Authorizations.reset_configuration
    AuthorizationModelsSpecHelper.create_db_tables
  end

  before do
    Authorizations.configure do |config|
      config.assignment_to(
        Authorizations::FakeJournal,
        authorizes: Authorizations::FakeTask,
        via: :fake_tasks)
      config.assignment_to(
        Authorizations::FakeJournal,
        authorizes: Authorizations::FakePaper,
        via: :fake_papers)
    end
  end

  after do
    Authorizations.reset_configuration
  end

  let!(:user) { FactoryGirl.create(:user, first_name: 'Bob Theuser') }
  let!(:journal) { Authorizations::FakeJournal.create }

  let!(:paper_assigned_to_journal) do
    Authorizations::FakePaper.create(fake_journal: journal)
  end

  let!(:other_paper_on_same_journal) do
    Authorizations::FakePaper.create(fake_journal: journal)
  end

  permissions do
    permission action: 'read', applies_to: Authorizations::FakePaper.name
    permission action: 'view', applies_to: Authorizations::FakePaper.name
    permission(
      action: 'write',
      applies_to: Authorizations::FakePaper.name,
      states: %w(in_progress))
    permission(
      action: 'talk',
      applies_to: Authorizations::FakePaper.name,
      states: %w(in_progress in_review))

    permission action: 'view', applies_to: Authorizations::FakeTask.name
    permission action: 'edit', applies_to: Authorizations::FakeTask.name
    permission action: 'edit', applies_to: Authorizations::FakeTask.name, states: %w(unsubmitted)
    permission action: 'discuss', applies_to: Authorizations::FakeTask.name
  end

  role :editor do
    has_permission action: 'read', applies_to: Authorizations::FakePaper.name
    has_permission action: 'write', applies_to: Authorizations::FakePaper.name, states: %w(in_progress)
    has_permission action: 'view', applies_to: Authorizations::FakePaper.name
    has_permission action: 'talk', applies_to: Authorizations::FakePaper.name, states: %w(in_progress in_review)
  end

  role :with_view_access_to_task do
    has_permission action: 'view', applies_to: Authorizations::FakeTask.name
    has_permission action: 'discuss', applies_to: Authorizations::FakeTask.name
    has_permission action: 'edit', applies_to: Authorizations::FakeTask.name, states: %w(unsubmitted)
  end

  role :with_edit_access_to_task do
    has_permission action: 'view', applies_to: Authorizations::FakeTask.name
    has_permission action: 'edit', applies_to: Authorizations::FakeTask.name, states: %w[*]
  end

  before do
    assign_user user, to: paper_assigned_to_journal, with_role: role_editor
    assign_user user, to: other_paper_on_same_journal, with_role: role_editor
  end

  describe '#serializable' do
    it "returns a hash of all the user's permissions for the returned object" do
      results = user.filter_authorized(:*, Authorizations::FakePaper.all)
      expect(results.serializable.map(&:as_json)).to eq([
        {
          id: 'fakePaper+1',
          object: {
            id: paper_assigned_to_journal.id,
            type: Authorizations::FakePaper.name
          },
          permissions: {
            read: { states: %w[*] },
            view: { states: %w[*] }
          }
        },
        {
          id: 'fakePaper+2',
          object: {
            id: other_paper_on_same_journal.id,
            type: Authorizations::FakePaper.name
          },
          permissions: {
            read: { states: %w[*] },
            view: { states: %w[*] }
          }
        }
      ].as_json)
    end

    describe <<-DESC do
      and the user has access thru multiple assignments
    DESC
      let!(:paper) { Authorizations::FakePaper.create!(fake_journal: journal) }
      let!(:task) { Authorizations::FakeTask.create!(fake_paper: paper) }

      before do
        Authorizations.reset_configuration
        Authorizations.configure do |config|
          config.assignment_to(
            Authorizations::FakePaper,
            authorizes: Authorizations::FakeTask,
            via: :fake_tasks)
        end

        assign_user user, to: paper, with_role: role_with_view_access_to_task
        assign_user user, to: task, with_role: role_with_edit_access_to_task
      end

      it <<-DESC do
        returns the permissions for all permissible assignments including
        combining the states for each role
      DESC
        results = user.filter_authorized(:*, Authorizations::FakeTask.all)
        permission_hash = results.serializable[0].as_json["permissions"]

        expect(permission_hash["edit"]["states"])
          .to contain_exactly("*")

        expect(permission_hash["view"]["states"])
          .to contain_exactly("*")

        expect(permission_hash["discuss"]["states"])
          .to contain_exactly("*")
      end
    end
  end
end
