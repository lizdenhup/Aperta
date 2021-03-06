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

FactoryGirl.define do
  # This trait is building a task but using FactoryGirl stubs for associations
  # it normally depends on. This reduces the time it takes to construct the
  # task.
  #
  # It is placed outside of a particular factory so that it can be reused
  # from any factories defined within the engines.
  trait :with_stubbed_associations do
    paper { FactoryGirl.build_stubbed(:paper) }
    phase { FactoryGirl.build_stubbed(:phase) }
    card_version { FactoryGirl.build_stubbed(:card_version) }
    sequence(:position)
  end

  factory :task do
    transient do
      # any array of participants that are passed in
      # will be used to set the participants of the task
      participants nil
    end

    trait :with_card do
      after(:create) do |task|
        # first check to see if there's an existing card we can use
        name = task.class.to_s
        Card.find_by(name: name) || FactoryGirl.create(:card, :versioned, name: name)
      end
    end

    trait :with_loaded_card do
      after(:build) do |task|
        CardLoader.load(task.class.name)
        card = Card.find_by_class_name(task.class)
        task.update(card_version: card.latest_published_card_version)
      end
    end

    after(:build) do |task, evaluator|
      unless evaluator.paper
        task.paper = FactoryGirl.create(:paper)
      end

      unless evaluator.phase
        task.phase = FactoryGirl.create(:phase, paper: task.paper)
      end

      unless evaluator.card_version
        card = FactoryGirl.create(:card, journal: task.paper.journal)
        task.card_version = FactoryGirl.create(:card_version, card: card)
      end
    end

    after(:create) do |task, evaluator|
      if evaluator.participants
        task.participations.destroy_all
        evaluator.participants.each { |user| task.add_participant(user) }
      end
    end

    factory :ad_hoc_task, class: 'AdHocTask' do
      title "Do something awesome"
    end

    factory :assign_team_task, class: 'Tahi::AssignTeam::AssignTeamTask' do
      title "Assign Team"
    end

    factory :authors_task, class: 'TahiStandardTasks::AuthorsTask' do
      title "Authors"
    end

    factory :billing_task, class: 'PlosBilling::BillingTask' do
      title "Billing"
      trait :with_card_content do
        after(:create) do |task|
          task.card.content_for_version_without_root(:latest).each do |card_content|
            value = "#{card_content.ident} answer"
            value = 'bob@example.com' if card_content.ident == 'plos_billing--email'
            task.find_or_build_answer_for(card_content: card_content, value: value)
          end
        end
      end
    end

    factory :changes_for_author_task, class: 'PlosBioTechCheck::ChangesForAuthorTask' do
      title "Changes for Author"
      body initialTechCheckBody: 'Default changes for author body'
    end

    factory :custom_card_task, class: 'CustomCardTask' do
      title "Custom Card"
    end

    factory :competing_interests_task, class: 'CustomCardTask' do
      title "Competing Interests"
    end

    factory :data_availability_task, class: 'TahiStandardTasks::DataAvailabilityTask' do
      title "Data Availability"
    end

    factory :editors_discussion_task, class: 'PlosBioInternalReview::EditorsDiscussionTask' do
      title "Editor Discussion"
    end

    factory :figure_task, class: 'TahiStandardTasks::FigureTask' do
      title "Figures"
    end

    # Can be removed after APERTA-10460 has been moved to production
    factory :legacy_financial_disclosure_task, class: 'TahiStandardTasks::FinancialDisclosureTask' do
      title "Financial Disclosure"
    end

    factory :financial_disclosure_task, class: 'CustomCardTask' do
      title "Financial Disclosure"
    end

    factory :final_tech_check_task, class: 'PlosBioTechCheck::FinalTechCheckTask' do
      title 'Final Tech Check'
    end

    factory :front_matter_reviewer_report_task, class: 'TahiStandardTasks::FrontMatterReviewerReportTask' do
      title "Front Matter Reviewer Report"
    end

    factory :initial_decision_task, class: 'TahiStandardTasks::InitialDecisionTask' do
      title "Initial Decision"
    end

    factory :initial_tech_check_task, class: 'PlosBioTechCheck::InitialTechCheckTask' do
      title 'Initial Tech Check'
    end

    factory :invitable_task, class: 'InvitableTestTask' do
      paper { FactoryGirl.create(:paper, :submitted_lite) }
      title "Invitable Task"
    end

    factory :metadata_task, class: 'MetadataTestTask' do
      title "Metadata Task"
    end

    factory :paper_editor_task, class: 'TahiStandardTasks::PaperEditorTask' do
      title "Invite Editor"
    end

    factory :paper_reviewer_task, class: 'TahiStandardTasks::PaperReviewerTask' do
      title 'Invite Reviewers'
    end

    factory :production_metadata_task, class: "TahiStandardTasks::ProductionMetadataTask" do
      title "Production Metadata"
    end

    factory :reporting_guidelines_task, class: 'TahiStandardTasks::ReportingGuidelinesTask' do
      title "Reporting Guidelines"
    end

    factory :related_articles_task, class: 'TahiStandardTasks::RelatedArticlesTask' do
      title "Related Articles"
    end

    factory :register_decision_task, class: 'TahiStandardTasks::RegisterDecisionTask' do
      title "Register Decision"
    end

    factory :reviewer_recommendations_task, class: 'TahiStandardTasks::ReviewerRecommendationsTask' do
      title "Reviewer Candidates"
    end

    factory :reviewer_report_task, class: 'TahiStandardTasks::ReviewerReportTask' do
      title "Reviewer Report"
    end

    factory :revise_task, class: 'TahiStandardTasks::ReviseTask' do
      title "Revise Manuscript"
    end

    factory :revision_tech_check_task, class: 'PlosBioTechCheck::RevisionTechCheckTask' do
      title 'Revision Tech Check'
    end

    factory :send_to_apex_task, class: 'TahiStandardTasks::SendToApexTask' do
      title 'Send to Apex'
    end

    factory :similarity_check_task, class: 'TahiStandardTasks::SimilarityCheckTask' do
      phase
      paper
      title 'Similarity Check'
    end

    factory :supporting_information_task, class: 'TahiStandardTasks::SupportingInformationTask' do
      title "Supporting Information"
    end

    factory :taxon_task, class: 'TahiStandardTasks::TaxonTask' do
      title "Taxon"
    end

    factory :title_and_abstract_task, class: 'TahiStandardTasks::TitleAndAbstractTask' do
      title 'Title and Abstract'
    end

    factory :upload_manuscript_task, class: 'TahiStandardTasks::UploadManuscriptTask' do
      title "Upload Manuscript"
    end
  end
end

class MetadataTestTask < Task
  include MetadataTask

  DEFAULT_TITLE = 'Mock Metadata Task'.freeze
end

class InvitableTestTask < Task
  include Invitable

  DEFAULT_TITLE = 'Test Task'.freeze
  DEFAULT_ROLE_HINT = 'user'.freeze

  def invitation_invited(_invitation)
    :invited
  end

  def invitation_accepted(_invitation)
    :accepted
  end

  def invitation_declined(_invitation)
    :declined
  end

  def invitation_rescinded(_invitation)
    :rescinded
  end

  def active_model_serializer
    ::TaskSerializer
  end

  def invitee_role
    'test role'
  end
end
