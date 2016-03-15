require 'rails_helper'

describe Author do
  subject(:author) { FactoryGirl.build(:author) }

  def setup_contribution_question_for_author
    NestedQuestion.where(owner_type: Author.name).delete_all
    contributions_question = FactoryGirl.create(:nested_question,
      owner_id: nil,
      owner_type: Author.name,
      ident: Author::CONTRIBUTIONS_QUESTION_IDENT,
      value_type: "question-set",
      text: "Author Contributions")

    contributions_question.children << FactoryGirl.create(:nested_question,
      owner_id: nil,
      owner_type: Author.name,
      ident: "conceived_and_designed_experiments",
      parent: contributions_question,
      value_type: "boolean",
      text: "Conceived and designed the experiments")
  end

  context "validation" do
    it "will be valid with default factory data" do
      expect(author.valid?).to be(true)
    end

    context "and the corresponding authors_task is completed" do
      let(:authors_task) { TahiStandardTasks::AuthorsTask.new(completed: true) }

      before do
        # we need a saved author in order to associated answers
        author.save!
        setup_contribution_question_for_author
        author._task = authors_task
      end

      it "is not valid without contributions" do
        expect(author.contributions.empty?).to be(true)
        expect(author.valid?).to be(false)
      end

      it "is valid with at least one contribution" do
        question = NestedQuestion.where(ident: "conceived_and_designed_experiments").first!
        answer = FactoryGirl.create(
          :nested_question_answer,
          nested_question: question,
          owner: author)
        expect(author.contributions.empty?).to be(false)
        expect(author.valid?).to be(true)
      end
    end
  end

  describe "#contributions" do
    let(:question_that_does_belong_to_contributions) do
      FactoryGirl.create(:nested_question,
        owner_id: nil,
        owner_type: Author.name,
        parent: Author.contributions_question,
        value_type: "boolean",
        text: "Conceived and designed the experiments")
    end

    let(:question_that_does_not_belong_to_contributions) do
      FactoryGirl.create(:nested_question,
        owner_id: nil,
        owner_type: Author.name,
        parent: nil,
        value_type: "boolean",
        text: "Conceived and designed the experiments")
    end

    before do
      # need to save author in order to associate answers
      author.save!
      setup_contribution_question_for_author
      question_that_does_belong_to_contributions
      question_that_does_not_belong_to_contributions
    end

    it "returns an array of contributions (e.g. any answered question under the contributions question-set)" do
      answer_that_should_be_included = FactoryGirl.build(:nested_question_answer,
        nested_question: question_that_does_belong_to_contributions,
        owner: author
      )

      answer_that_should_not_be_included = FactoryGirl.build(:nested_question_answer,
        nested_question: question_that_does_not_belong_to_contributions,
        owner: author
      )

      author.nested_question_answers << answer_that_should_be_included
      author.nested_question_answers << answer_that_should_not_be_included

      expect(author.contributions).to eq([answer_that_should_be_included])
    end

    context "when there are no contributions" do
      it "returns an empty array" do
        expect(author.contributions.empty?).to be(true)
      end
    end
  end

  # TODO: move these tests to the TahiStandardTasks engines
  describe ".task-completed?" do
    let(:authors_task) { TahiStandardTasks::AuthorsTask.new }

    it "is true when task is complete" do
      authors_task.completed = true
      expect(subject.class.new(task: authors_task)).to be_task_completed
    end

    it "is false when task is incomplete" do
      authors_task.completed = false
      expect(subject.class.new(task: authors_task)).to_not be_task_completed
    end

    it "is false when there is no task" do
      expect(subject.class.new(task: nil)).to_not be_task_completed
    end
  end
end
