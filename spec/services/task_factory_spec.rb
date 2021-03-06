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

describe TaskFactory do
  let(:paper) { FactoryGirl.create(:paper) }
  let(:phase) { FactoryGirl.create(:phase, paper: paper) }
  let(:klass) { TahiStandardTasks::ReviseTask }

  before do
    CardLoader.load("TahiStandardTasks::ReviseTask")
  end

  it "Creates a task" do
    expect do
      TaskFactory.create(klass, paper: paper, phase: phase)
    end.to change { Task.count }.by(1)
  end

  it "calls the task's task_added_to_paper hook" do
    expect_any_instance_of(klass).to receive(:task_added_to_paper)
    TaskFactory.create(klass, paper: paper, phase: phase)
  end

  it "Sets the default title if is not indicated" do
    task = TaskFactory.create(klass, paper: paper, phase: phase)
    expect(task.title).to eq('Response to Reviewers')
  end

  it "Sets the title from params" do
    task = TaskFactory.create(klass, paper: paper, phase: phase, title: 'Test')
    expect(task.title).to eq('Test')
  end

  it "Sets the phase on the task" do
    task = TaskFactory.create(klass, paper: paper, phase: phase)
    expect(task.phase).to eq(phase)
  end

  it "Sets the paper on the task" do
    task = TaskFactory.create(klass, paper: paper, phase: phase)
    expect(task.paper).to eq(paper)
  end

  it "Sets the phase to the task from params ID" do
    task = TaskFactory.create(klass, paper: paper, phase_id: phase.id)
    expect(task.phase).to eq(phase)
  end

  it "Sets the phase to the task from params paper_id" do
    task = TaskFactory.create(klass, paper_id: paper.id, phase: phase)
    expect(task.paper).to eq(paper)
  end

  it "Sets the body from params" do
    task = TaskFactory.create(klass, paper: paper, phase: phase, body: { key: 'value' })
    expect(task.body).to eq('key' => 'value')
  end

  describe "setting task's card version" do
    context "the card version is passed in" do
      let(:card_version) { FactoryGirl.create(:card_version) }
      it "assigns the card version to the task" do
        task = TaskFactory.create(klass, paper: paper, phase: phase, card_version: card_version)
        expect(task.card_version).to eq(card_version)
      end
    end

    context "the card version is not present in the options" do
      let(:klass) { TahiStandardTasks::UploadManuscriptTask }

      context "a card with a matching name as the task exists" do
        let!(:existing_card) do
          FactoryGirl.create(:card, :versioned, name: klass.name, journal: nil)
        end

        it "uses the latest version of that card" do
          task = TaskFactory.create(klass, paper: paper, phase: phase)
          expect(task.card_version).to eq(existing_card.latest_card_version)
        end
      end
    end
  end
end
