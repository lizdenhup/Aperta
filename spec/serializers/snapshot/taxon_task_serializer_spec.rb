require "rails_helper"

describe Snapshot::TaxonTaskSerializer do
  subject(:serializer) { described_class.new(task) }
  let(:task) { FactoryGirl.create(:taxon_task) }

  describe "#as_json" do
    it "serializes to JSON" do
      expect(serializer.as_json).to include(
        name: "taxon-task",
        type: "properties"
      )
    end

    context "serializing related nested questions" do
      it_behaves_like "snapshot serializes related nested questions", resource: :task
    end
  end
end
