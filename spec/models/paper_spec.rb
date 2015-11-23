require 'rails_helper'

describe Paper do
  let(:paper) { FactoryGirl.create :paper }
  let(:user) { FactoryGirl.create :user }

  context "#create" do
    it "also create Decision" do
      expect(paper.decisions.length).to eq 1
      expect(paper.decisions.first.class).to eq Decision
    end

    it "can set body on creation" do
      paper_new = FactoryGirl.create :paper, body: 'foo'
      expect(paper_new.body).to eq('foo')
      expect(paper_new.latest_version.text).to eq('foo')
    end

    it "can use body= before save" do
      paper_new = FactoryGirl.build :paper
      paper_new.body = 'foo'
      expect(paper_new.body).to eq('foo')
      paper.save!
      paper.reload
      expect(paper_new.body).to eq('foo')
    end

    describe "after_create doi callback" do
      it "the doi is not set coming from factory girl before create" do
        unsaved_paper_from_factory_girl = FactoryGirl.build :paper
        expect(unsaved_paper_from_factory_girl.doi).to eq(nil)
      end

      it "sets a doi in after_create callback" do
        journal                 = FactoryGirl.create :journal, :with_doi
        last_doi_initial        = journal.last_doi_issued
        paper                   = FactoryGirl.create :paper, journal: journal

        expect(paper.doi).to be_truthy
        expect(last_doi_initial.succ).to eq(journal.last_doi_issued) #is incremented in journal
        expect(journal.last_doi_issued).to eq(paper.doi.split('.')[1])
      end
    end
  end

  describe "#destroy" do
    subject { paper.destroy }

    it "is successful" do
      expect(subject).to eq paper
      expect(subject.destroyed?).to eq true
    end

    context "with tasks" do
      let(:paper) { FactoryGirl.create(:paper, :with_tasks) }

      it "delete Phases and Tasks" do
        expect(paper).to have_at_least(1).phase
        expect(paper).to have_at_least(1).task
        paper.destroy

        expect(Phase.where(paper_id: paper.id).count).to be 0
        expect(Task.count).to be 0
      end
    end
  end

  describe "validations" do
    describe "paper_type" do
      it "is required" do
        paper = Paper.new title: 'Example'
        expect(paper).to_not be_valid
        expect(paper).to have(1).errors_on(:paper_type)
      end
    end

    describe "metadata_tasks_completed?" do
      context "paper with completed metadata task" do
        let(:paper) do
          FactoryGirl.create(:paper_with_task, task_params: { type: "MockMetadataTask", completed: true })
        end

        it "returns true" do
          expect(paper.metadata_tasks_completed?).to eq(true)
        end
      end

      context "paper with incomplete metadata task" do
        let(:paper) do
          FactoryGirl.create(:paper_with_task, task_params: { type: "MockMetadataTask", completed: false })
        end

        it "returns false" do
          expect(paper.metadata_tasks_completed?).to eq(false)
        end
      end
    end

    describe "short_title" do
      it "is within 255 chars" do
        paper = FactoryGirl.build(:paper, title: "Example", short_title: "a" * 256)
        expect(paper).to_not be_valid
        expect(paper).to have(1).errors_on(:short_title)

        paper.short_title = "a" * 254
        expect(paper).to be_valid

        paper.short_title = "a" * 255
        expect(paper).to be_valid
      end
    end

    describe "journal" do
      it "must be present" do
        paper = Paper.new(title: 'YOLO')
        expect(paper).to_not be_valid
      end
    end
  end

  context 'State Machine' do
    describe '#initial_submit' do
      it 'transitions to initially_submitted' do
        paper.initial_submit!
        expect(paper).to be_initially_submitted
      end

      it 'marks the paper not editable' do
        paper.initial_submit!
        expect(paper).to_not be_editable
      end

      it 'sets the updated_at of the initial version' do
        Timecop.freeze(Time.current.utc) do
          paper.initial_submit!
          expect(paper.submitted_at).to eq(Time.current.utc)
        end
      end
    end

    describe '#submit!' do

      it "does not transition when metadata tasks are incomplete" do
        expect(paper).to receive(:metadata_tasks_completed?).and_return(false)
        expect{ paper.submit! user }.to raise_error(AASM::InvalidTransition)
      end

      it "transitions to submitted" do
        expect(paper).to receive(:metadata_tasks_completed?).and_return(true)
        paper.submit! user
        expect(paper).to be_submitted
      end

      it "marks the paper not editable" do
        expect(paper).to receive(:metadata_tasks_completed?).and_return(true)
        paper.submit! user
        expect(paper).to_not be_editable
      end

      it "sets the submitting_user of the latest version" do
        paper.submit! user
        expect(paper.latest_version.submitting_user).to eq(user)
      end

      it "sets the updated_at of the latest version" do
        paper.latest_version.update!(updated_at: Time.zone.now - 10.days)
        paper.submit! user
        expect(paper.latest_version.updated_at.utc).to be_within(1.second).of Time.zone.now
      end

      it 'sets first_submitted_at once' do
        paper.submit! user
        expect(paper.first_submitted_at.utc).to(
          be_within(1.second).of Time.zone.now)

        first_submitted = paper.first_submitted_at
        paper.minor_revision!
        paper.submit! user
        expect(paper.first_submitted_at).to be(first_submitted)
      end

      it "broadcasts 'paper:submitted' event" do
        allow(Notifier).to receive(:notify)
        expect(Notifier).to receive(:notify).with(hash_including(event: "paper:submitted")) do |args|
          expect(args[:data][:record]).to eq(paper)
        end
        paper.submit! user
      end
    end

    describe '#withdraw!' do
      let(:paper) { FactoryGirl.create(:paper, :submitted) }

      it "transitions to withdrawn without a reason" do
        paper.withdraw!
        expect(paper).to be_withdrawn
      end

      it "transitions to withdrawn with a reason" do
        paper.withdraw! "Don't want to."
        expect(paper.withdrawn?).to eq true
      end

      it "marks the paper not editable" do
        paper.withdraw!
        expect(paper).to_not be_editable
      end
    end

    describe '#invite_full_submission' do
      let(:paper) { FactoryGirl.create(:paper, :initially_submitted) }

      it 'transitions to invited_for_full_submission' do
        paper.invite_full_submission!
        expect(paper.publishing_state).to eq('invited_for_full_submission')
      end

      it 'marks the paper editable' do
        paper.invite_full_submission!
        expect(paper).to be_editable
      end

      it 'sets a new minor version' do
        expect(paper.latest_version.version_string).to match(/^R0.0/)
        paper.invite_full_submission!
        expect(paper.latest_version.version_string).to match(/^R0.1/)
      end
    end

    describe '#reactivate!' do
      let(:paper) { FactoryGirl.create(:paper, :submitted) }

      it "transitions to the previous state" do
        paper.withdraw!
        expect(paper).to be_withdrawn
        paper.reload.reactivate!
        expect(paper).to be_submitted
      end

      it "marks the paper with the previous editable state for submitted papers" do
        paper.withdraw!
        expect(paper).to_not be_editable
        paper.reload.reactivate!
        expect(paper).to_not be_editable
        expect(paper.submitted?).to eq(true)
      end

      it "marks the paper with the previous editable state for unsubmitted papers" do
        paper = FactoryGirl.create(:paper, :unsubmitted)
        expect(paper).to be_editable
        paper.withdraw!
        expect(paper).to_not be_editable
        paper.reload.reactivate!
        expect(paper).to be_editable
        expect(paper.unsubmitted?).to eq(true)
      end
    end

    describe '#minor_check!' do
      let(:paper) { FactoryGirl.create(:paper, :submitted) }

      it "marks the paper editable" do
        paper.minor_check!
        expect(paper).to be_editable
      end

      it "creates a new minor version" do
        expect(paper.latest_version.version_string).to match(/^R0.0/)
        paper.minor_check!
        expect(paper.latest_version.version_string).to match(/^R0.1/)
      end
    end

    describe '#submit_minor_check!' do
      let(:paper) { FactoryGirl.create(:paper, :submitted) }

      it "marks the paper uneditable" do
        paper.minor_check!
        paper.submit_minor_check! user
        expect(paper).to_not be_editable
      end

      it "sets the submitting_user of the latest version" do
        paper.minor_check!
        paper.submit_minor_check! user
        expect(paper.latest_version.submitting_user).to eq(user)
      end

      it "sets the updated_at of the latest version" do
        paper.minor_check!
        paper.latest_version.update!(updated_at: Time.zone.now - 10.days)
        paper.submit_minor_check! user
        expect(paper.latest_version.updated_at.utc).to be_within(1.second).of Time.zone.now
      end
    end

    describe '#reject' do
      it 'transitions to rejected state from submitted' do
        paper = FactoryGirl.create(:paper, :submitted)
        paper.reject!
        expect(paper.rejected?).to be true
      end

      it 'transitions to rejected state from initially_submitted' do
        paper = FactoryGirl.create(:paper, :initially_submitted)
        paper.reject!
        expect(paper.rejected?).to be true
      end
    end

    describe '#publish!' do
      let(:paper) { FactoryGirl.create(:paper, :submitted) }

      it "marks the paper uneditable" do
        paper.publish!
        expect(paper.published_at).to be_truthy
      end
    end
  end

  describe "#make_decision" do
    let(:paper) { FactoryGirl.create(:paper, :submitted) }

    context "acceptance" do
      let(:decision) do
        FactoryGirl.create(:decision, verdict: "accept")
      end

      it "accepts the paper" do
        paper.make_decision decision
        expect(paper.publishing_state).to eq("accepted")
      end

      it 'sets accepted_at!' do
        paper.make_decision decision
        expect(paper.accepted_at.utc).to be_within(1.second).of Time.zone.now
      end
    end

    context "rejection" do
      it 'rejects the paper' do
        decision = instance_double('Decision', verdict: 'reject')
        expect(paper).to receive(:reject!)
        paper.make_decision decision
      end
    end

    context "major revision" do
      let(:decision) do
        FactoryGirl.create(:decision, verdict: "major_revision")
      end

      it "puts the paper in_revision" do
        paper.make_decision decision
        expect(paper.publishing_state).to eq("in_revision")
      end

      it "creates a new major version" do
        expect(paper.latest_version.version_string).to match(/^R0.0/)
        paper.make_decision decision
        expect(paper.latest_version.version_string).to match(/^R1.0/)
      end
    end

    context "minor revision" do
      let(:decision) do
        FactoryGirl.create(:decision, verdict: "minor_revision")
      end

      it "puts the paper in_revision" do
        paper.make_decision decision
        expect(paper.publishing_state).to eq("in_revision")
      end

      it "creates a new major version" do
        expect(paper.latest_version.version_string).to match(/^R0.0/)
        paper.make_decision decision
        expect(paper.latest_version.version_string).to match(/^R1.0/)
      end
    end
  end

  describe "#major_version" do
    before { expect(paper.latest_version).to be }

    it "returns the latest version's major_version" do
      expect(paper.major_version).to eq(paper.latest_version.major_version)
    end

    context "when there is no latest_version" do
      before do
        paper.versioned_texts.destroy_all
        expect(paper.latest_version).to be(nil)
      end

      it "returns nil" do
        expect(paper.major_version).to be(nil)
      end
    end
  end

  describe "#minor_version" do
    before { expect(paper.latest_version).to be }

    it "returns the latest version's minor_version" do
      expect(paper.major_version).to eq(paper.latest_version.minor_version)
    end

    context "when there is no latest_version" do
      before do
        paper.versioned_texts.destroy_all
        expect(paper.latest_version).to be(nil)
      end

      it "returns nil" do
        expect(paper.major_version).to be(nil)
      end
    end
  end

  describe "callbacks" do
    let(:user) { FactoryGirl.create(:user) }
    let(:paper) { FactoryGirl.build :paper, creator: user }

    it "assigns all author tasks to the paper author" do
      paper.save!
      author_tasks = Task.where(role: 'author', phase_id: paper.phases.pluck(:id))
      other_tasks = Task.where("role != 'author'", phase_id: paper.phases.pluck(:id))
      expect(author_tasks.all? { |t| t.assignee == user }).to eq true
      expect(other_tasks.all? { |t| t.assignee != user }).to eq true
    end

    context "when the paper is persisted" do
      before { paper.save! }

      it "assigns all author tasks to the paper author" do
        tasks = Task.where(role: 'author', phase_id: paper.phases.map(&:id))
        not_author = FactoryGirl.create(:user)
        paper.update! creator: not_author
        expect(tasks.all? { |t| t.assignee == user }).to eq true
      end
    end
  end

  describe "#editor" do
    let(:user) { FactoryGirl.create(:user) }
    context "when the paper has an editor" do
      before { create(:paper_role, :editor, paper: paper, user: user) }
      specify { expect(paper.editors).to include(user) }
    end

    context "when the paper doesn't have an editor" do
      specify { expect(paper.editors).to be_empty }
    end
  end

  describe "#role_for" do
    let(:user) { FactoryGirl.create :user }

    before do
      create(:paper_role, :editor, paper: paper, user: user)
    end

    it "returns roles if the role exist for the given user and role type" do
      expect(paper.role_for(user: user, role: 'editor')).to be_present
    end

    context "when the role isn't found" do
      it "returns nothing" do
        expect(paper.role_for(user: user, role: 'chucknorris')).to_not be_present
      end
    end
  end

  describe "#abstract" do
    before do
      paper.update(body: "a bunch of words")
    end

    context "with an #abstract field value" do
      before do
        paper.update(abstract: "an abstract about a bunch of words")
      end

      it "returns #abstract" do
        expect(paper.abstract).to eq "an abstract about a bunch of words"
      end
    end

    context "without an #abstract field value" do
      it "returns #default_abstract" do
        expect(paper.abstract).to eq "a bunch of words"
      end
    end
  end

  describe "#authors_list" do
    let!(:author1) { FactoryGirl.create :author, paper: paper }
    let!(:author2) { FactoryGirl.create :author, paper: paper }

    it "returns authors' last name, first name and affiliation name in an ordered list" do
      expect(paper.authors_list).to eq "1. #{author1.last_name}, #{author1.first_name} from #{author1.affiliation}\n2. #{author2.last_name}, #{author2.first_name} from #{author2.affiliation}"
    end
  end

  describe "#latest_version" do
    before do
      # create a bunch of old minor versions
      FactoryGirl.create(:versioned_text, paper: paper, major_version: 0, minor_version: 1)
      FactoryGirl.create(:versioned_text, paper: paper, major_version: 0, minor_version: 2)
      FactoryGirl.create(:versioned_text, paper: paper, major_version: 0, minor_version: 3)
    end

    it "returns the latest version" do
      versioned_text = FactoryGirl.create(:versioned_text, paper: paper, major_version: 1, minor_version: 0)
      expect(paper.latest_version).to eq(versioned_text)
    end
  end

  describe "#resubmitted?" do
    let(:paper) { FactoryGirl.create(:paper) }

    context "with pending decisions" do
      before do
        paper.decisions.first.update!(verdict: nil)
      end

      specify { expect(paper.resubmitted?).to eq(true) }
    end

    context "with non-pending decisions" do
      before do
        paper.decisions.first.update!(verdict: "accept")
      end

      specify { expect(paper.resubmitted?).to eq(false) }
    end

    context "with no decisions" do
      before do
        paper.decisions.destroy_all
      end

      specify { expect(paper.resubmitted?).to eq(false) }
    end
  end

  describe "#display_title" do
    context "title and short_title are nil" do
      # user has not provided a title and is expecting ihat to extract one,
      # but ihat could not find one
      let(:paper) { FactoryGirl.build(:paper, title: nil, short_title: nil) }

      context "with sanitization" do
        it "is an empty string" do
          expect(paper.display_title).to eq("")
        end
      end

      context "without sanitization" do
        it "is an empty string" do
          expect(paper.display_title(sanitized: false)).to eq("")
        end
      end
    end

    context "title is present, short title is nil" do
      let(:paper) { FactoryGirl.build(:paper, title: "<b>my long paper</b>", short_title: nil) }

      context "with sanitization" do
        it "it is sanitized title" do
          expect(paper.display_title).to eq("my long paper")
        end
      end

      context "without sanitization" do
        it "is is unsanitized title" do
          expect(paper.display_title(sanitized: false)).to eq("<b>my long paper</b>")
        end
      end
    end

    context "title is nil, short title is present" do
      let(:paper) { FactoryGirl.build(:paper, title: nil, short_title: "<b>my paper</b>") }

      context "with sanitization" do
        it "it is sanitized title" do
          expect(paper.display_title).to eq("my paper")
        end
      end

      context "without sanitization" do
        it "is is unsanitized title" do
          expect(paper.display_title(sanitized: false)).to eq("<b>my paper</b>")
        end
      end
    end

    context "title is present, short title is present" do
      let(:paper) { FactoryGirl.build(:paper, title: "<b>my long paper</b>", short_title: "<b>my paper</b>") }

      context "with sanitization" do
        it "it is sanitized title" do
          expect(paper.display_title).to eq("my long paper")
        end
      end

      context "without sanitization" do
        it "is is unsanitized title" do
          expect(paper.display_title(sanitized: false)).to eq("<b>my long paper</b>")
        end
      end
    end
  end
end
