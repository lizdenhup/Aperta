require 'spec_helper'

describe PaperRole do
  let(:paper) { FactoryGirl.create :paper, :with_tasks }
  describe "scopes" do
    describe "reviewers_for" do
      let(:user) { FactoryGirl.build(:user) }
      it "returns reviewers for a given paper" do
        reviewer_paper_role = PaperRole.create!(reviewer: true, paper: paper, user: user)
        other_paper_role = PaperRole.create!(paper: paper, user: user)

        expect(PaperRole.reviewers_for(paper)).to_not include other_paper_role
        expect(PaperRole.reviewers_for(paper)).to include reviewer_paper_role
      end
    end
  end

  describe "callbacks" do
    let(:default_task_attrs) { { title: 'A title', role: 'editor', phase: paper.phases.first } }

    describe "after_save" do
      let(:bob)   { FactoryGirl.create(:user) }
      let(:steve) { FactoryGirl.create(:user) }

      context "when the assignee is not changing" do
        it "does not modify other tasks" do
          paper_role = PaperRole.create! user: bob, paper: paper, editor: true
          task = Task.create! default_task_attrs
          paper_role.update! reviewer: true
          expect(task.reload.assignee).to be_nil
        end
      end

      context "when the role is not editor" do
        it "does not modify other tasks" do
          task = Task.create! default_task_attrs
          paper_role = PaperRole.create! user: bob, paper: paper, editor: false
          expect(task.reload.assignee).to be_nil
        end
      end

      context "when there are editor tasks with no assignee" do
        it "assigns the task to the PaperEditorTask assignee" do
          task = Task.create! default_task_attrs
          paper_role = PaperRole.create! user: bob, paper: paper, editor: true
          expect(task.reload.assignee).to eq(bob)
        end
      end

      context "when there are editor tasks with the old assignee" do
        it "assigns the task to the PaperEditorTask assignee" do
          task = Task.create! default_task_attrs.merge(assignee: bob)
          paper_role = PaperRole.create! user: steve, paper: paper, editor: true
          expect(task.reload.assignee).to eq(steve)
        end
      end

      context "when there are editor tasks assigned to another editor" do
        let(:dave) { FactoryGirl.create(:user) }

        it "does not assign the task to the PaperEditorTask assignee" do
          paper_role = PaperRole.create! user: bob, paper: paper, editor: true
          task = Task.create! default_task_attrs.merge(assignee: dave)
          paper_role.update! user: steve
          expect(task.reload.assignee).to eq(dave)
        end
      end

      context "when there are completed tasks" do
        it "does not assign the task to the PaperEditorTask assignee" do
          task = Task.create! default_task_attrs.merge(assignee: bob, completed: true)
          paper_role = PaperRole.create! user: steve, paper: paper, editor: true
          expect(task.reload.assignee).to eq(bob)
        end
      end
    end
  end

end
