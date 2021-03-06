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

# Specs to ensure that PaperFactory generates models that contain all the
# necessary setup.

describe 'PaperFactory' do
  let(:creator) { FactoryGirl.create(:user) }
  let(:journal) { FactoryGirl.create(:journal) }
  let(:reference_paper) do
    Timecop.freeze(time_freeze) do
      FactoryGirl.create(:paper, title: title, journal: journal)
    end
  end
  let(:time_freeze) { 1.day.ago }
  let(:title) { Faker::Lorem.words(10) .join(" ") }

  describe 'default' do
    describe '#build_stubbed' do
      let(:paper) { FactoryGirl.build_stubbed(:paper, journal: journal) }

      it 'builds a valid paper' do
        expect(paper).to be_an_instance_of(Paper)
        expect(paper).to be_valid
      end
    end

    describe '#create' do
      let(:paper) { FactoryGirl.create(:paper) }

      it 'creates a single, valid paper' do
        expect { paper }.to change { Paper.count }.from(0).to(1)
      end
    end
  end

  describe 'submitted_lite trait' do
    describe "#build_stubbed" do
      let(:paper_submitted_lite) { FactoryGirl.build_stubbed(:paper, :submitted_lite) }

      it 'builds a valid paper' do
        expect(paper_submitted_lite).to be_an_instance_of(Paper)
        expect(paper_submitted_lite).to be_valid
      end
    end

    describe "#create" do
      let(:paper_submitted_lite) do
        Timecop.freeze(time_freeze) do
          # Persisting to the db changes the precision of the timestamps. Reload
          # to ensure that they are comparable.
          FactoryGirl.create(
            :paper,
            :submitted_lite,
            title: title,
            journal: journal,
            submitting_user: creator).reload
        end
      end

      before do
        Timecop.freeze(time_freeze) do
          reference_paper.submit! creator
          reference_paper.reload
        end
      end

      it 'creates a single, valid paper' do
        expect { paper_submitted_lite }.to change { Paper.count }.by(1)
      end

      it 'should be equal' do
        expect(paper_submitted_lite).to mostly_eq(reference_paper).except('id', 'doi', 'short_doi')
      end

      it 'should have equal decisions' do
        expect(paper_submitted_lite.decisions)
          .to mostly_eq(reference_paper.decisions).except('id', 'paper_id')
      end

      it 'should have equal versioned_texts' do
        expect(paper_submitted_lite.versioned_texts)
          .to mostly_eq(reference_paper.versioned_texts).except('id', 'paper_id')
      end
    end
  end

  describe 'ready_for_export trait' do
    subject(:paper) { create :paper, :ready_for_export }

    it 'creates a paper ready for export' do
      expect(paper).to be
      expect(paper.publishing_state).to eq 'accepted'
    end
  end

  describe 'withdrawn_lite' do
    let(:attributes) do
      {
        title: title,
        journal: journal,
        reason: reason,
        withdrawn_by_user: creator
      }
    end
    let(:reason) { Faker::Lorem.sentence }

    describe "#build_stubbed" do
      subject(:paper_withdrawn_lite) do
        FactoryGirl.build_stubbed(:paper, :withdrawn_lite)
      end

      it "builds a valid paper instance" do
        expect(paper_withdrawn_lite).to be_an_instance_of(Paper)
        expect(paper_withdrawn_lite).to be_valid
      end
    end

    describe "#create" do
      subject(:paper_withdrawn_lite) do
        Timecop.freeze(time_freeze) do
          # Persisting to the db changes the precision of the timestamps. Reload
          # to ensure that they are comparable.
          FactoryGirl.create(
            :paper,
            :withdrawn_lite,
            title: title,
            journal: journal,
            reason: reason,
            withdrawn_by_user: creator).reload
        end
      end

      before do
        Timecop.freeze(time_freeze) do
          reference_paper.withdraw! reason, creator
        end
        reference_paper.reload
      end

      it 'creates one paper' do
        expect { paper_withdrawn_lite }.to change { Paper.count }.by(1)
      end

      it 'is equal to a paper that has been withdrawn' do
        expect(paper_withdrawn_lite).to mostly_eq(reference_paper).except('id', 'doi', 'short_doi')
      end

      it 'have equal withdrawal records' do
        expect(reference_paper.withdrawals).to be_present
        expect(paper_withdrawn_lite.withdrawals).to mostly_eq(reference_paper.withdrawals).except('id', 'paper_id')
      end
    end
  end
end
