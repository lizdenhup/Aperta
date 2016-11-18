require "rails_helper"

describe Snapshot::EarlyPostingTaskSerializer do
  subject(:serializer) { described_class.new(task) }
  let(:task) { FactoryGirl.create(:early_posting_task) }

  describe "#as_json" do
    it "serializes to JSON" do
      expect(serializer.as_json).to include(
        name: "early-posting-task",
        type: "properties"
      )
    end

    context "serializing related nested questions" do
      it_behaves_like "snapshot serializes related nested questions", resource: :task
    end
  end
end
