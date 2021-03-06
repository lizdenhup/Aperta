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
  By default, permissions aren't tied to specific states, but they can be.

  Any object that implements a required_permission_id column and
  required_permission association can restrict access to a specific permission.
DESC
  include AuthorizationSpecHelper

  let!(:user) { FactoryGirl.create(:user) }
  let!(:paper) { Authorizations::FakePaper.create! }
  let!(:task) { Authorizations::FakeTask.create!(fake_paper: paper) }

  before(:all) do
    Authorizations.reset_configuration
    AuthorizationModelsSpecHelper.create_db_tables
  end

  after do
    Authorizations.reset_configuration
  end

  permissions do
    permission(
      action: 'edit',
      applies_to: Authorizations::FakePaper.name,
      states: %w(unsubmitted in_revision)
    )
    permission(
      action: 'edit',
      applies_to: Authorizations::FakeTask.name,
      states: %w(unsubmitted in_revision)
    )
  end

  role :with_access_to_edit do
    has_permission(
      action: 'edit',
      applies_to: Authorizations::FakePaper.name,
      states: %w(unsubmitted in_revision)
    )
  end

  role :with_access_to_edit_task do
    has_permission(
      action: 'edit',
      applies_to: Authorizations::FakeTask.name,
      states: %w(unsubmitted in_revision)
    )
  end

  context <<-DESC do
    when a user has access to an object that has requires a specific state
    BUT the object IS NOT IN that state
  DESC

    before do
      assign_user user, to: paper, with_role: role_with_access_to_edit
      paper.update! publishing_state: nil
    end

    it 'denies them access' do
      expect(user.can?(:edit, paper)).to be(false)
    end

    it 'does not include unauthorized objects' do
      expect(
        user.filter_authorized(:edit, Authorizations::FakePaper.all).objects
      ).to_not include(paper)
    end
  end

  context <<-DESC do
    when a user has access to an object that requires a specific state
    AND the object IS IN that state
  DESC
    before do
      assign_user user, to: paper, with_role: role_with_access_to_edit
      paper.update! publishing_state: 'unsubmitted'
    end

    it 'grants them access' do
      expect(user.can?(:edit, paper)).to be(true)
    end

    it 'includes authorized objects' do
      expect(
        user.filter_authorized(:edit, Authorizations::FakePaper.all).objects
      ).to include(paper)
    end
  end

  context <<-DESC do
    when a user has access to an object through an association and it's
    in an permissible state
  DESC
    before do
      Authorizations.configure do |config|
        config.assignment_to(
          Authorizations::FakeTask,
          authorizes: Authorizations::FakePaper,
          via: :fake_paper
        )
      end

      assign_user user, to: task, with_role: role_with_access_to_edit
      paper.update! publishing_state: 'in_revision'
    end

    it 'grants them access' do
      expect(user.can?(:edit, paper)).to be(true)
    end

    it 'includes authorized objects' do
      expect(
        user.filter_authorized(:edit, Authorizations::FakePaper.all).objects
      ).to include(paper)
    end
  end

  context <<-DESC do
    when a user has direct access to an object that delegates its state
  DESC
    before do
      assign_user user, to: task, with_role: role_with_access_to_edit_task
    end

    context 'and the delegated state is permissible' do
      it 'grants them access' do
        paper.update! publishing_state: 'in_revision'
        expect(user.can?(:edit, task)).to be(true)
        expect(
          user.filter_authorized(:edit, Authorizations::FakeTask.all).objects
        ).to include(task)
      end
    end

    context 'and the delegated state is not permissible' do
      it 'denies them access' do
        paper.update! publishing_state: 'foo'
        expect(user.can?(:edit, task)).to be(false)
        expect(
          user.filter_authorized(:edit, Authorizations::FakeTask.all).objects
        ).not_to include(task)
      end
    end
  end

  context <<-DESC do
    when a user has access to an object through an association that delegates
    its state
  DESC
    before do
      Authorizations.configure do |config|
        config.assignment_to(
          Authorizations::FakePaper,
          authorizes: Authorizations::FakeTask,
          via: :fake_tasks
        )
      end
      assign_user user, to: paper, with_role: role_with_access_to_edit_task
    end

    context 'and the delegated state is permissible' do
      it 'grants them access' do
        paper.update! publishing_state: 'in_revision'
        expect(user.can?(:edit, task)).to be(true)
        expect(
          user.filter_authorized(:edit, Authorizations::FakeTask.all).objects
        ).to include(task)
      end
    end

    context 'and the delegated state is not permissible' do
      it 'denies them access' do
        paper.update! publishing_state: 'foo'
        expect(user.can?(:edit, task)).to be(false)
        expect(
          user.filter_authorized(:edit, Authorizations::FakeTask.all).objects
        ).not_to include(task)
      end
    end
  end
end
