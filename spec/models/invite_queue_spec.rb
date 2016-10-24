require 'rails_helper'

describe InviteQueue do
  def make_queue(invite_array)
    q = FactoryGirl.create :invite_queue, invitations: invite_array

    invite_array.each_with_index do |i, pos|
      Invitation.where(id: i.id).update_all(position: pos + 1)
      i.reload
    end
    q
  end

  let(:paper) { FactoryGirl.create(:paper) }
  let(:task) { FactoryGirl.create(:paper_editor_task, paper: paper) }

  describe "#add_invite" do
    let(:queue) do
      make_queue [
        ungrouped_1,
        ungrouped_2
      ]
    end
    let(:invitation) { FactoryGirl.create(:invitation, task: task, paper: paper) }
    it 'should add the invitation to the bottom of the queue' do
      queue.add_invite(invitation)
      expect(invitation.invite_queue).to eq(queue)
      expect(invitation.reload.position).to eq(3)
    end
  end

  let(:group_1_primary) do
    FactoryGirl.create(:invitation, task: task, paper: paper, body: 'group_1_primary')
  end

  let(:g1_alternate_1) do
    FactoryGirl.create(:invitation, primary: group_1_primary, task: task, paper: paper, body: 'g1_alternate_1')
  end

  let(:g1_alternate_2) do
    FactoryGirl.create(:invitation, primary: group_1_primary, task: task, paper: paper, body: 'g1_alternate_2')
  end

  let(:g1_alternate_3) do
    FactoryGirl.create(:invitation, primary: group_1_primary, task: task, paper: paper, body: 'g1_alternate_3')
  end

  let(:group_2_primary) do
    FactoryGirl.create(:invitation, task: task, paper: paper, body: 'group_2_primary')
  end

  let(:g2_alternate_1_sent) do
    FactoryGirl.create(:invitation, :invited, primary: group_2_primary, task: task, paper: paper, body: 'g2_alternate_1_sent')
  end

  let(:g2_alternate_2) do
    FactoryGirl.create(:invitation, primary: group_2_primary, task: task, paper: paper, body: 'g2_alternate_2')
  end

  let(:sent_1) { FactoryGirl.create(:invitation, :invited, task: task, paper: paper, body: 'sent_1') }
  let(:sent_2) { FactoryGirl.create(:invitation, :invited, task: task, paper: paper, body: 'sent_2') }

  let(:ungrouped_1) { FactoryGirl.create(:invitation, task: task, paper: paper, body: 'ungrouped_1') }
  let(:ungrouped_2) { FactoryGirl.create(:invitation, task: task, paper: paper, body: 'ungrouped_2') }
  let(:ungrouped_3) { FactoryGirl.create(:invitation, task: task, paper: paper, body: 'ungrouped_3') }

  describe "#valid_positions_for_invite" do
    let(:full_queue) do
      make_queue [
        group_1_primary, # 1
        g1_alternate_1, # 2
        g1_alternate_2, # 3
        g1_alternate_3, # 4
        group_2_primary, # 5
        g2_alternate_1_sent, # 6
        g2_alternate_2, # 7
        sent_1, # 8
        sent_2, # 9
        ungrouped_1, # 10
        ungrouped_2, # 11
        ungrouped_3  # 12
      ]
    end

    it "an ungrouped primary can go to the position of other ungrouped primaries" do
      expect(full_queue.valid_positions_for_invite(ungrouped_1)).to eq([11, 12])
      expect(full_queue.valid_positions_for_invite(ungrouped_2)).to eq([10, 12])
    end

    it "an alternate can go to the position of another unsent alternate in its group" do
      expect(full_queue.valid_positions_for_invite(g1_alternate_1)).to eq([3, 4])
      expect(full_queue.valid_positions_for_invite(g1_alternate_2)).to eq([2, 4])
      expect(full_queue.valid_positions_for_invite(g2_alternate_2)).to eq([])
    end

    it "a grouped primary has no valid positions" do
      expect(full_queue.valid_positions_for_invite(group_1_primary)).to eq([])
    end

    it "sent (invited) invites have no valid positions" do
      expect(full_queue.valid_positions_for_invite(sent_1)).to eq([])
    end
  end

  let(:small_queue) do
    make_queue [
      group_1_primary, # 1
      g1_alternate_1, # 2
      sent_1, # 3
      ungrouped_1, # 4
      ungrouped_2, # 5
    ]
  end

  describe "#assign_primary" do
    context "error cases" do
      it "blows up if the invite is an alternate.  primaries need to be unassigned first" do
        expect { small_queue.assign_primary(invite: g1_alternate_1, primary: ungrouped_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the invite and the primary don't belong to the same queue" do
        some_other_primary = FactoryGirl.create :invitation,
          task: task,
          paper: paper,
          invite_queue: nil
        expect { small_queue.assign_primary(invite: g1_alternate_1, primary: some_other_primary) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the invite is a primary with alternates." do
        expect { small_queue.assign_primary(invite: group_1_primary, primary: ungrouped_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the invite is not in a pending state" do
        group_1_primary.update(state: "invited")
        expect { small_queue.assign_primary(invite: group_1_primary, primary: ungrouped_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the primary is an alternate" do
        expect { small_queue.assign_primary(invite: ungrouped_1, primary: g1_alternate_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "the invite and the primary are both ungrouped" do
      it "places the primary and the new alternate at the very top of the queue" do
        small_queue.assign_primary(invite: ungrouped_2, primary: ungrouped_1)
        expect(ungrouped_1.reload.position).to eq(1)
        expect(ungrouped_2.reload.position).to eq(2)
      end
    end

    context "the invite is ungrouped, the primary already has alternates" do
      it "places the new alternate below the existing alternates" do
        small_queue.assign_primary(invite: ungrouped_1, primary: group_1_primary)
        expect(ungrouped_1.reload.position).to eq(3)
        expect(group_1_primary.reload.position).to eq(1)
      end
    end
  end

  describe "#unassign_primary_from" do
    context "error cases" do
      let(:small_queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
          ungrouped_1, # 4
        ]
      end
      it "blows up if the invite is a primary with alternates." do
        expect { small_queue.unassign_primary_from(group_1_primary) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the invite has no primary" do
        expect { small_queue.unassign_primary_from(ungrouped_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "blows up if the invite is not in a pending state" do
        g1_alternate_1.update(state: "invited")
        expect { small_queue.unassign_primary_from(g1_alternate_1) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "the primary has other alternates" do
      let(:small_queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
          g1_alternate_2, # 3
          ungrouped_1, # 4
        ]
      end

      it "The alternate should no longer be linked as an alternate" do
        small_queue.unassign_primary_from(g1_alternate_1)
        expect(g1_alternate_1.reload.primary).to be_blank
      end

      it "moves the ungrouped invite to the bottom of the list" do
        small_queue.unassign_primary_from(g1_alternate_1)
        expect(group_1_primary.reload.position).to eq(1) # the primary should stay put
        expect(g1_alternate_1.reload.position).to eq(4)
      end
    end

    context "the primary has no other alternates" do
      let(:small_queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
          ungrouped_1, # 3
        ]
      end

      it "The alternate should no longer be linked as an alternate" do
        small_queue.unassign_primary_from(g1_alternate_1)
        expect(g1_alternate_1.reload.primary).to be_blank
      end

      it <<-DESC.strip_heredoc do
        moves the newly-ungrouped primary and the ungrouped invite to the bottom of the list.
        The ungrouped primary is now just another regular invitation
      DESC
        small_queue.unassign_primary_from(g1_alternate_1)
        expect(group_1_primary.reload.position).to eq(2)
        expect(g1_alternate_1.reload.position).to eq(3)
      end
    end
  end

  describe "#remove_invite" do
    context "the invite is an ungrouped primary" do
      let(:small_queue) do
        make_queue [
          ungrouped_1, # 1
          ungrouped_2, # 2
        ]
      end

      it "removes the invite from the list and repositions the other invites" do
        small_queue.remove_invite(ungrouped_1)
        expect(small_queue.invitations.pluck(:id)).to_not include(ungrouped_1.id)
        expect(ungrouped_2.reload.position).to eq(1)
      end
    end

    context "the invite is an alternate" do
      context "the primary has other alternates" do
        let(:small_queue) do
          make_queue [
            group_1_primary, # 1
            g1_alternate_1, # 2
            g1_alternate_2, # 3
            ungrouped_1, # 4
          ]
        end

        it "removes the invite from the queue, unsets the primary, and reorders the list" do
          small_queue.remove_invite(g1_alternate_1)
          expect(small_queue.invitations.pluck(:id)).to_not include(g1_alternate_1.id)
          expect(g1_alternate_1.primary_id).to be_blank
          expect(group_1_primary.reload.position).to eq(1) # the primary should stay put
          expect(ungrouped_1.reload.position).to eq(3)
        end
      end

      context "the primary has no other alternates" do
        let(:small_queue) do
          make_queue [
            group_1_primary, # 1
            g1_alternate_1, # 2
            ungrouped_1, # 3
          ]
        end

        it "removes the invite from the queue's invites and moves the newly-ungrouped primary to the bottom of the list" do
          small_queue.remove_invite(g1_alternate_1)
          expect(small_queue.invitations.pluck(:id)).to_not include(g1_alternate_1.id)
          expect(group_1_primary.reload.position).to eq(2)
        end
      end
    end

    context "the invite is a primary with alternates" do
      let(:small_queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
        ]
      end

      it "blows up. invites must be first ungrouped before they can be removed from the queue" do
        expect { small_queue.remove_invite(group_1_primary) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "#send_invite" do
    let(:queue) do
      make_queue [
        ungrouped_1, # 1
      ]
    end

    it "calls 'invite!'" do
      expect(ungrouped_1).to receive(:invite!)
      queue.send_invite(ungrouped_1)
    end

    context "the invite is an ungrouped primary" do
      context "there are existing sent invitations" do
        let(:queue) do
          make_queue [
            group_2_primary, # 1
            g2_alternate_2, # 2
            sent_1, # 3
            ungrouped_1, # 4
            ungrouped_2, # 5
          ]
        end

        it "gets repositioned to the bottom of the sent invitations" do
          queue.send_invite(ungrouped_2)
          expect(ungrouped_2.reload.position).to eq(4)
        end
      end

      context "there are groups but no sent invitations" do
        let(:queue) do
          make_queue [
            group_2_primary, # 1
            g2_alternate_2, # 2
            ungrouped_1, # 3
            ungrouped_2, # 4
          ]
        end

        it "gets repositioned after the end of the groups" do
          queue.send_invite(ungrouped_2)
          expect(ungrouped_2.reload.position).to eq(3)
        end
      end
    end

    context "the invite is a primary with alternates" do
      let(:queue) do
        make_queue [
          group_2_primary, # 1
          g2_alternate_1_sent, # 2
          g2_alternate_2, # 3
        ]
      end
      it "does not get repositioned" do
        queue.send_invite(group_2_primary)
        expect(group_2_primary.reload.position).to eq(1)
      end
    end

    context "the invite is an alternate" do
      let(:g2_alternate_3) do
        FactoryGirl.create(:invitation, primary: group_2_primary, task: task, paper: paper, body: 'g2_alternate_3')
      end

      let(:queue) do
        make_queue [
          group_1_primary, # 1
          g1_alternate_1, # 2
          group_2_primary, # 3
          g2_alternate_1_sent, # 4
          g2_alternate_2, # 5
          g2_alternate_3 # 6
        ]
      end

      it "gets repositioned to the bottom of the sent alternates for its primary" do
        queue.send_invite(g2_alternate_3)
        expect(g2_alternate_3.reload.position).to eq(5)

        queue.send_invite(g1_alternate_1.reload) # reload since acts_as_list has changed its position
        expect(g1_alternate_1.reload.position).to eq(2)
      end
    end
  end
end
