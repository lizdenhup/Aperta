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
DESC
  include AuthorizationSpecHelper

  subject(:user) { FactoryGirl.create(:user) }
  let!(:paper) { Authorizations::FakePaper.create! }
  let!(:task_a) { Authorizations::FakeTask.create!(fake_paper: paper, name: 'foo') }
  let!(:task_b) { Authorizations::FakeTask.create!(fake_paper: paper, name: 'bar') }
  let!(:task_c) { Authorizations::FakeTask.create!(fake_paper: paper) }

  before(:all) do
    AuthorizationModelsSpecHelper.create_db_tables
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema.define do
        add_column :permissions, :filter_by_name, :text
      end
    end
    Permission.reset_column_information
  end

  before(:each) do
    Authorizations.reset_configuration
    Authorizations.configure do |config|
      config.assignment_to(
        Authorizations::FakePaper,
        authorizes: Authorizations::FakeTask,
        via: :fake_tasks
      )
    end
  end

  after(:all) do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema.define do
        remove_column :permissions, :filter_by_name
      end
    end
    Permission.reset_column_information
  end

  after(:each) do
    Authorizations.reset_configuration
  end

  permissions do
    permission(
      action: 'edit',
      applies_to: Authorizations::FakeTask.name,
      filter_by_name: 'foo'
    )
    permission(
      action: 'view',
      applies_to: Authorizations::FakeTask.name
    )
  end

  role :with_access do
    has_permission(
      action: 'edit',
      applies_to: Authorizations::FakeTask.name,
      filter_by_name: 'foo'
    )
    has_permission(
      action: 'view',
      applies_to: Authorizations::FakeTask.name
    )
  end

  shared_examples_for :a_defined_filter do
    it { is_expected.to be_able_to(:edit, task_a) }

    it 'cannot edit a task with a non-matching name' do
      expect(subject).not_to be_able_to(:edit, task_b)
    end

    it 'cannot edit a task without a name' do
      expect(subject).not_to be_able_to(:edit, task_c)
    end

    it { is_expected.to be_able_to(:view, task_a, task_b, task_c) }

    describe 'filter_authorized' do
      it 'return the right stuff for :edit' do
        map = subject.filter_authorized(:edit, Authorizations::FakeTask.all).map
        expect(map).to contain_exactly([task_a, { 'edit' => { states: ['*'] } }])
      end

      it 'return the right stuff for :view' do
        map = subject.filter_authorized(:view, Authorizations::FakeTask.all).map
        expect(map).to contain_exactly([task_a, { 'view' => { states: ['*'] } }],
                                       [task_b, { 'view' => { states: ['*'] } }],
                                       [task_c, { 'view' => { states: ['*'] } }])
      end

      it 'return the right stuff for :*' do
        map = subject.filter_authorized(:*, Authorizations::FakeTask.all).map
        expect(map).to contain_exactly([task_a, { 'edit' => { states: ['*'] },
                                                  'view' => { states: ['*'] } }],
                                       [task_b, { 'view' => { states: ['*'] } }],
                                       [task_c, { 'view' => { states: ['*'] } }])
      end
    end
  end

  shared_examples_for :expected do
    context 'without defining a filter' do
      # Not defining a filter means that all permissions will apply. That is why
      # this should allow the user to edit task_a.
      it { is_expected.to be_able_to(:edit, task_a, task_b, task_c) }
      it { is_expected.to be_able_to(:view, task_a, task_b, task_c) }
    end

    context 'with a filter for another class' do
      before(:each) do
        Authorizations.configure do |config|
          config.filter(Authorizations::FakePaper, :filter_by_name) do |query, column, table|
            query.where(column.eq(nil).or(column.eq(table[:name])))
          end
        end
      end

      it { is_expected.to be_able_to(:edit, task_a, task_b, task_c) }
      it { is_expected.to be_able_to(:view, task_a, task_b, task_c) }
    end

    context 'defining a filter' do
      before(:each) do
        Authorizations.configure do |config|
          config.filter(Authorizations::FakeTask, :filter_by_name) do |query, column, table|
            query.where(column.eq(nil).or(column.eq(table[:name])))
          end
        end
      end

      it_behaves_like :a_defined_filter
    end
  end

  context 'direct assignment' do
    before(:each) do
      assign_user user, to: task_a, with_role: role_with_access
      assign_user user, to: task_b, with_role: role_with_access
      assign_user user, to: task_c, with_role: role_with_access
    end

    it_behaves_like :expected
  end

  context 'indirect assignment' do
    before(:each) do
      assign_user user, to: paper, with_role: role_with_access
    end

    it_behaves_like :expected
  end

  context 'with a filter using a join' do
    let!(:paper_a) { Authorizations::FakePaper.create!(name: 'foo') }
    let!(:paper_b) { Authorizations::FakePaper.create!(name: 'bar') }
    let!(:paper_c) { Authorizations::FakePaper.create!(name: nil) }
    let!(:task_a) { Authorizations::FakeTask.create!(fake_paper: paper_a, name: 'foo') }
    let!(:task_b) { Authorizations::FakeTask.create!(fake_paper: paper_b, name: 'foo') }
    let!(:task_c) { Authorizations::FakeTask.create!(fake_paper: paper_c, name: 'foo') }

    before(:each) do
      Authorizations.configure do |config|
        config.filter(
          Authorizations::FakeTask,
          :filter_by_name
        ) do |query, column, table|
          papers = Authorizations::FakePaper.arel_table.alias
          query
            .join(papers).on(papers[:id].eq(table[:fake_paper_id]))
            .where(column.eq(nil).or(column.eq(papers[:name])))
        end
      end
    end

    context 'direct assignment' do
      before(:each) do
        assign_user user, to: task_a, with_role: role_with_access
        assign_user user, to: task_b, with_role: role_with_access
        assign_user user, to: task_c, with_role: role_with_access
      end

      it_behaves_like :a_defined_filter
    end

    context 'indirect assignment' do
      before(:each) do
        assign_user user, to: paper_a, with_role: role_with_access
        assign_user user, to: paper_b, with_role: role_with_access
        assign_user user, to: paper_c, with_role: role_with_access
      end

      it_behaves_like :a_defined_filter
    end
  end
end
