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

describe CustomCard::Migrator do
  let(:journal) { FactoryGirl.create(:journal, name: 'the only one') }
  let(:paper) { FactoryGirl.create(:paper, journal: journal) }
  let(:phase) { FactoryGirl.create(:phase, paper: paper) }
  let(:task) { FactoryGirl.create(:paper_reviewer_task, paper: paper, phase: phase, card_version: existing_card.latest_card_version) }
  let!(:existing_card) { FactoryGirl.create(:card, :versioned, journal: journal, name: "TahiStandardTasks::PaperReviewerTask") }
  let(:content) { task.card.latest_card_version.card_contents.first }
  let!(:answer) { FactoryGirl.create(:answer, paper: paper, owner: task, card_content: content) }
  let(:configuration) do
    Class.new do
      def self.name
        'Review The Paper'
      end

      def self.task_class
        'TahiStandardTasks::PaperReviewerTask'
      end
    end
  end

  context 'new card is not published' do
    let!(:new_card) { FactoryGirl.create(:card, :versioned, :draft, journal: journal, name: 'Review The Paper') }
    it 'does not migrate task card version' do
      expect {
        CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: configuration).migrate
      }.to_not change { Task.find(task.id).card_version_id }
    end

    it 'does not delete legacy card' do
      expect {
        CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: configuration).migrate
        Card.find(task.card.id)
      }.to_not raise_error
    end

    it 'does not migrate answer card content id' do
      expect {
        CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: configuration).migrate
      }.to_not change { answer.reload.card_content_id }
    end
  end

  context 'the new card is published' do
    let!(:new_card) { FactoryGirl.create(:card, :versioned, journal: journal, name: 'Review The Paper') }

    # The migrator fails if the old and new card don't have the same set of idents
    before do
      new_card.latest_published_card_version.card_contents.first.update(ident: 'test ident')
      existing_card.latest_published_card_version.card_contents.first.update(ident: 'test ident')
    end

    it 'migrates task card version' do
      expect {
        CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: configuration).migrate
      }.to(change { Task.find(task.id).card_version_id })
    end

    it 'migrates answer card content id' do
      expect {
        CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: configuration).migrate
      }.to(change { answer.reload.card_content_id })
    end

    it 'deletes the legacy card' do
      expect {
        CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: configuration).migrate
        Card.find(task.card.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'sets the existing task type based on the configuration task_class' do
      task_id = task.id
      CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: configuration).migrate
      expect(Task.find(task_id).type).to eq('TahiStandardTasks::PaperReviewerTask')
    end

    it 'changes existing Task titles to match the name in the configuration class' do
      task.update(title: "Some other title")
      CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: configuration).migrate
      expect(task.reload.title).to eq('Review The Paper')
    end

    it 'changes existing TaskTemplate titles to match the name in the configuration class' do
      jtt = FactoryGirl.create(:journal_task_type,
                               journal: journal,
                               kind: 'TahiStandardTasks::PaperReviewerTask')
      task_template = FactoryGirl.create(:task_template,
                                         journal_task_type: jtt,
                                         title: 'Old Title')

      CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: configuration).migrate
      expect(task_template.reload.title).to eq('Review The Paper')
    end

    it 'the new task type can be something different than the original' do
      other_configuration = Class.new do
        def self.name
          'Review The Paper'
        end

        def self.task_class
          'CustomCardTask'
        end
      end

      task_id = task.id
      CustomCard::Migrator.new(legacy_task_klass_name: task.type, configuration_class: other_configuration).migrate
      expect(Task.find(task_id).type).to eq('CustomCardTask')
    end
  end
end
