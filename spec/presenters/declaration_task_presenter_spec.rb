require 'spec_helper'

describe DeclarationTaskPresenter do
  include Rails.application.routes.url_helpers

  describe "#data_attributes" do
    let(:task) do
      paper = Paper.create! title: "Foo bar", short_title: "Foo", journal: Journal.create!
      allow(paper).to receive(:declarations).and_return [
        double(:declaration, slice: { question: 'Q1', answer: 'A1', id: 1 }),
        double(:declaration, slice: { question: 'Q2', answer: 'A2', id: 2 })
      ]
      task = DeclarationTask.create! title: "Paper Admin",
        completed: true,
        role: 'admin',
        phase: paper.task_manager.phases.first
      allow(task).to receive(:paper).and_return paper
      task
    end

    subject(:data_attributes) { DeclarationTaskPresenter.new(task).data_attributes }

    it "includes standard task data" do
      expect(data_attributes).to include 'card-name' => 'declaration'
    end

    it "includes custom figure data" do
      expect(data_attributes).to include(
        'declarations' => '[{"question":"Q1","answer":"A1","id":1},{"question":"Q2","answer":"A2","id":2}]',
      )
    end
  end
end
