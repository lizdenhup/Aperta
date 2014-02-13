require 'spec_helper'

class FakeTaskPresenter
  def initialize *args
  end
end

class FakeTask
end

describe TaskPresenter do
  include Rails.application.routes.url_helpers

  describe ".for" do
    let(:task) { FakeTask.new }
    specify { expect(TaskPresenter.for(task)).to be_a FakeTaskPresenter }
  end

  describe "#data_attributes" do
    let :admin do
      User.create! username: 'worker',
        first_name: 'Andi', last_name: 'Admin',
        password: 'password', password_confirmation: 'password',
        email: 'worker@example.org',
        admin: true
    end

    let :task do
      paper = Paper.create! title: "Foo bar", short_title: "Foo", journal: Journal.create!
      Task.create! title: "Verify Signatures",
        assignee: admin,
        completed: true,
        body: 'Too many muscles!',
        role: 'admin',
        phase: paper.task_manager.phases.first
    end

    it_behaves_like "all tasks, which have common attributes" do
      let(:card_name) { 'task' }
    end
  end
end
