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

describe CardPermissions do
  let(:journal) { FactoryGirl.create(:journal) }
  let(:user) { FactoryGirl.create(:user) }
  let(:card) { FactoryGirl.create(:card, journal: journal) }
  let(:action) { 'eat' }
  let(:role) { FactoryGirl.create(:role, journal: journal, name: Faker::Name.title) }
  let(:query) { { action: action, applies_to: 'Task', filter_by_card_id: card.id } }

  shared_examples_for "a non-state-limited permission for view" do
    context 'and the action is view' do
      let(:action) { 'view' }

      it 'should not limit the permission by state' do
        subject
        perm = role.permissions.where(query).first
        expect(perm.states.pluck(:name)).to contain_exactly('*')
      end

      it 'should return the permissions' do
        expect(subject).to contain_exactly(*Permission.where(applies_to: 'Task', filter_by_card_id: card))
      end
    end
  end

  shared_examples_for "permission creator" do
    it "should create 3 permissions" do
      expect { subject }.to change {
        Permission.where(filter_by_card_id: card).count
      }.from(0).to(3)
    end

    it "should create a new permission with a wildcard state" do
      subject
      expect(role.permissions.find_by(query)).to be
      expect(role.permissions.find_by(query).applies_to).to eq('Task')
    end

    it 'should return the permissions' do
      expect(subject).to contain_exactly(*Permission.where(applies_to: 'Task', filter_by_card_id: card))
    end

    context 'when the role is creator' do
      let(:role) { FactoryGirl.create(:role, journal: journal, name: 'Creator') }

      it_should_behave_like 'a non-state-limited permission for view'

      it "should assign the role to editable states permission only" do
        subject
        perm = role.permissions.where(action: action).first
        expect(perm.states.pluck(:name)).to contain_exactly(*Paper::EDITABLE_STATES.map(&:to_s))
      end
    end

    context 'when the role is a collaborator' do
      let(:role) { FactoryGirl.create(:role, journal: journal, name: 'Collaborator') }

      it_should_behave_like 'a non-state-limited permission for view'

      it "should assign the role to editable states permission only" do
        subject
        perm = role.permissions.where(action: action).first
        expect(perm.states.pluck(:name)).to contain_exactly(*Paper::EDITABLE_STATES.map(&:to_s))
      end
    end

    context 'when the role is a reviewer' do
      let(:role) { FactoryGirl.create(:role, journal: journal, name: 'Reviewer') }

      it_should_behave_like 'a non-state-limited permission for view'

      it "should assign the role to editable states permission only" do
        subject
        perm = role.permissions.where(action: action).first
        expect(perm.states.pluck(:name)).to contain_exactly(*Paper::REVIEWABLE_STATES.map(&:to_s))
      end
    end

    context 'when the action is view' do
      let(:action) { 'view' }

      it 'should create a view permission on the CardVersion' do
        subject
        expect(role.permissions.where(action: 'view', applies_to: 'CardVersion', filter_by_card_id: card.id).count).to be(1)
      end
    end
  end

  describe ".add_roles" do
    subject { CardPermissions.add_roles(card, action, [role]) }

    it_should_behave_like "permission creator"

    context 'when the permission already exists' do
      let!(:permission) do
        Permission.ensure_exists(
          action,
          applies_to: 'Task',
          role: role,
          states: [Permission::WILDCARD],
          filter_by_card_id: card.id
        )
      end
      let(:new_role) { FactoryGirl.create(:role, journal: journal, name: Faker::Name.title) }

      it 'adds the new role' do
        CardPermissions.add_roles(card, action, [new_role])
        expect(role.reload.permissions.reload.where(query).count).to be(1)
        expect(new_role.permissions.reload.where(query).count).to be(1)
      end
    end
  end

  describe '.set_roles' do
    subject { CardPermissions.set_roles(card, action, [role]) }

    it_should_behave_like "permission creator"

    context 'when the permission already exists' do
      let!(:permission) do
        Permission.ensure_exists(
          action,
          applies_to: 'Task',
          role: role,
          states: [Permission::WILDCARD],
          filter_by_card_id: card.id
        )
      end
      let(:new_role) { FactoryGirl.create(:role, journal: journal, name: Faker::Name.title) }

      it 'adds the new role and removes the old' do
        CardPermissions.set_roles(card, action, [new_role])
        expect(role.permissions.where(query).count).to be(0)
        expect(new_role.permissions.where(query).count).to be(1)
      end

      it 'adds the new role and removes the old if the permission is passed explicitly' do
        CardPermissions.set_roles(card, action, [new_role], permission)
        expect(role.permissions.where(query).count).to be(0)
        expect(new_role.permissions.where(query).count).to be(1)
      end
    end
  end
end
