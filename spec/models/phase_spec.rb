require 'spec_helper'

describe Phase do
  it "defines a DEFAULT_PHASE_NAME" do
    expect(Phase.const_defined? :DEFAULT_PHASE_NAMES).to be_truthy
  end

  describe ".default_phases" do
    before do
      stub_const "Phase::DEFAULT_PHASE_NAMES", %w(Todo Doing Done)
    end

    subject(:phases) { Phase.default_phases }

    it "returns an array of phase instances for each phase name" do
      expect(phases.size).to eq(3)
      expect(phases[0].name).to eq "Todo"
      expect(phases[1].name).to eq "Doing"
      expect(phases[2].name).to eq "Done"
    end

    it "does not persist any of the phases" do
      expect(phases.all? &:new_record?).to be true
    end
  end

  describe "initialization" do
    describe "tasks" do
      context "when the phase is a 'Needs Editor' phase" do
        let(:phase) { Phase.new name: 'Needs Editor' }

        it "initializes one paper admin task" do
          expect(phase.tasks.map(&:class)).to include(PaperAdminTask)
        end

        it "initializes one paper editor task" do
          expect(phase.tasks.map(&:class)).to include(PaperEditorTask)
        end
      end

      context "when the phase is not a 'Needs Editor' phase" do
        it "does not assign a paper admin task" do
          phase = Phase.new name: 'Custom Phase'
          expect(phase.tasks.map(&:class).any? { |c| c == PaperAdminTask }).to eq false
        end
      end

      context "when tasks are specified" do
        it "uses provided task" do
          tasks = [Task.new]
          phase = Phase.new name: 'Needs Editor', tasks: tasks
          expect(phase.tasks).to eq tasks
        end
      end
    end
  end
end
