require 'rails_helper'

describe DiscussionParticipantsController do
  let(:user) { FactoryGirl.create(:user) }
  let(:another_user) { FactoryGirl.create(:user) }
  let(:paper) { FactoryGirl.create(:paper, :with_integration_journal) }
  let!(:paper_role) { FactoryGirl.create(:paper_role, :editor, paper: paper, user: user) }
  let!(:topic_a) { FactoryGirl.create(:discussion_topic, paper: paper) }
  let!(:participation) { topic_a.discussion_participants.create!(user: user) }

  let(:json) { res_body }

  before { sign_in user }

  describe 'POST create' do
    include ActiveJob::TestHelper

    before { ActionMailer::Base.deliveries.clear }
    after  { clear_enqueued_jobs }

    let(:creation_params) do
      {
        discussion_participant: {
          discussion_topic_id: topic_a.id,
          user_id: another_user.id,
        }
      }
    end

    it_behaves_like "an unauthenticated json request"

    context "when the user has access" do
      before do
        allow(user).to receive(:can?)
          .with(:manage_participant, topic_a)
          .and_return true
      end

      it "adds a user to a discussion" do
        expect do
          xhr :post, :create, format: :json, **creation_params
        end.to change { DiscussionParticipant.count }.by(1)

        participant = json["discussion_participant"]
        expect(participant['discussion_topic_id']).to eq(topic_a.id)
        expect(participant['user_id']).to eq(another_user.id)
      end
    end

    context "when the user does not have access" do
      let!(:do_request) { post :create, creation_params }
      before do
        allow(user).to receive(:can?)
          .with(:manage_participant, topic_a)
          .and_return false
      end

      it { is_expected.to responds_with(403) }
    end
  end

  describe 'DELETE destroy' do
    subject(:do_request) do
      xhr :delete, :destroy, format: :json, id: participation.id
    end

    it_behaves_like "an unauthenticated json request"

    context "when the user has access" do
      before do
        stub_sign_in user
        allow(user).to receive(:can?)
          .with(:manage_participant, topic_a)
          .and_return true
      end

      it "destroys a participant" do
        expect do
          do_request
        end.to change { DiscussionParticipant.count }.by(-1)
      end
    end

    context "when the user does not have access" do
      subject(:do_request) { delete :destroy, id: topic_a.id }

      before do
        stub_sign_in user
        allow(user).to receive(:can?)
          .with(:manage_participant, topic_a)
          .and_return false
      end

      it { is_expected.to responds_with(403) }
    end
  end

end
