# coding: utf-8
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

# coding: utf-8
# JournalFactory is for creating new journals in Aperta. It gets them all
# set up: nice and right.

require 'custom_card/file_loader'

class JournalFactory
  def self.create(journal_params)
    journal = Journal.new(journal_params)
    new(journal).create
  end

  def self.ensure_default_roles_and_permissions_exist(journal)
    new(journal).ensure_default_roles_and_permissions_exist
  end

  def self.assign_hints(journal)
    new(journal).assign_hints
  end

  def initialize(journal)
    @journal = journal
  end

  def self.setup_default_mmt(journal)
    setup_default_task_types(journal)
    JournalServices::CreateDefaultManuscriptManagerTemplates.call(journal)
  end

  def self.setup_default_task_types(journal)
    JournalServices::CreateDefaultTaskTypes.call(journal)
  end

  def self.seed_letter_templates(journal)
    new(journal).seed_letter_templates
  end

  def create
    @journal.save!
    create_related_models_async
    @journal
  end

  def create_related_models_async
    JournalWorker.perform_async(@journal.id)
  end

  def create_related_models
    self.class.setup_default_mmt(@journal)
    ensure_default_roles_and_permissions_exist
    assign_hints
    seed_letter_templates
    assign_default_system_custom_cards
  end

  def assign_hint(names, hint)
    @journal.roles.where(name: names)
            .update_all(assigned_to_type_hint: hint)
  end

  def assign_hints
    assign_hint Role::DISCUSSION_TOPIC_ROLES, DiscussionTopic.name
    assign_hint Role::TASK_ROLES,             Task.name
    assign_hint Role::PAPER_ROLES,            Paper.name
    assign_hint Role::JOURNAL_ROLES,          Journal.name
  end

  def assign_default_system_custom_cards
    CustomCard::FileLoader.load(@journal)
  end

  # All standard tasks that users who see the workflow should see
  # Billing is special, and CustomCardTask is handled by a custom mechanism.
  STANDARD_TASKS = (Task.descendants - [PlosBilling::BillingTask, CustomCardTask]).freeze
  SUBMISSION_TASKS = (Task.submission_task_types - [CustomCardTask]).freeze

  # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  def ensure_default_roles_and_permissions_exist
    Role.ensure_exists(Role::CREATOR_ROLE, journal: @journal, participates_in: [Task, Paper]) do |role|
      # Paper
      role.ensure_permission_exists(:edit, applies_to: Paper, states: Paper::EDITABLE_STATES)
      role.ensure_permission_exists(:edit_authors, applies_to: Paper, states: Paper::EDITABLE_STATES)
      role.ensure_permission_exists(:submit, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: Paper)
      role.ensure_permission_exists(:withdraw, applies_to: Paper)
      role.ensure_permission_exists(:view_recent_activity, applies_to: Paper)

      # Creator(s) only get access to the submission task types
      task_klasses = SUBMISSION_TASKS
      task_klasses += [AdHocForAuthorsTask]
      task_klasses.each do |klass|
        role.ensure_permission_exists(:add_email_participants, applies_to: klass)
        role.ensure_permission_exists(:edit, applies_to: klass, states: Paper::EDITABLE_STATES)
        role.ensure_permission_exists(:manage_participant, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
        role.ensure_permission_exists(:view_participants, applies_to: klass)
      end
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::COLLABORATOR_ROLE, journal: @journal, participates_in: [Paper]) do |role|
      role.ensure_permission_exists(:submit, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: Paper)
      role.ensure_permission_exists(:edit_authors, applies_to: Paper)
      role.ensure_permission_exists(:view_recent_activity, applies_to: Paper)

      # Collaborators can view and edit any metadata card except billing
      task_klasses = SUBMISSION_TASKS
      task_klasses += [AdHocForAuthorsTask]
      task_klasses -= [PlosBilling::BillingTask]
      task_klasses.each do |klass|
        role.ensure_permission_exists(:edit, applies_to: klass, states: Paper::EDITABLE_STATES)
        role.ensure_permission_exists(:manage_participant, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
        role.ensure_permission_exists(:view_participants, applies_to: klass)
      end
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::COVER_EDITOR_ROLE, journal: @journal, participates_in: [Paper]) do |role|
      # Paper
      role.ensure_permission_exists(:assign_roles, applies_to: Paper)
      role.ensure_permission_exists(:edit, applies_to: Paper)
      role.ensure_permission_exists(:edit_authors, applies_to: Paper, states: Paper::EDITABLE_STATES)
      role.ensure_permission_exists(:edit_related_articles, applies_to: Paper)
      role.ensure_permission_exists(:manage_collaborators, applies_to: Paper)
      role.ensure_permission_exists(:manage_workflow, applies_to: Paper)
      role.ensure_permission_exists(:perform_similarity_check, applies_to: Paper)
      role.ensure_permission_exists(:register_decision, applies_to: Paper)
      role.ensure_permission_exists(:search_academic_editors, applies_to: Paper)
      role.ensure_permission_exists(:search_admins, applies_to: Paper)
      role.ensure_permission_exists(:search_reviewers, applies_to: Paper)
      role.ensure_permission_exists(:submit, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: Paper)
      role.ensure_permission_exists(:view_decisions, applies_to: Paper)
      role.ensure_permission_exists(:view_user_role_eligibility_on_paper, applies_to: Paper)
      role.ensure_permission_exists(:view_recent_activity, applies_to: Paper)

      # Cover editors cannot view, edit, or otherwise do anything on the
      # BillingTask, the ChangesForAuthorTask, or the PaperEditorTask
      task_klasses = STANDARD_TASKS - [
        PlosBioTechCheck::ChangesForAuthorTask,
        TahiStandardTasks::PaperEditorTask
      ]
      task_klasses.each do |klass|
        role.ensure_permission_exists(:add_email_participants, applies_to: klass)
        role.ensure_permission_exists(:manage, applies_to: klass)
        role.ensure_permission_exists(:manage_participant, applies_to: klass)
        role.ensure_permission_exists(:manage_scheduled_events, applies_to: klass)
        role.ensure_permission_exists(:view_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
        role.ensure_permission_exists(:view_participants, applies_to: klass)
      end

      # Cover Editors can edit _all_ tasks except for ReviewerReportTask(s).
      # Of those editable tasks all but the TitleAndAstractTask can only be
      # modified if the Paper itself is editable.
      editable_task_klasses = task_klasses -
        [TahiStandardTasks::ReviewerReportTask] -
        TahiStandardTasks::ReviewerReportTask.descendants -
        [TahiStandardTasks::TitleAndAbstractTask]
      editable_task_klasses.each do |klass|
        role.ensure_permission_exists(
          :edit,
          applies_to: klass,
          states: Paper::EDITABLE_STATES
        )
      end

      # The TitleAndAbstractTask is always editable, regardless of paper state.
      role.ensure_permission_exists(:edit, applies_to: TahiStandardTasks::TitleAndAbstractTask)

      # Discussions
      role.ensure_permission_exists(:edit, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:manage_participant, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:reply, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:start_discussion, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::REVIEWER_ROLE, journal: @journal, participates_in: [Paper]) do |role|
      role.ensure_permission_exists(:view, applies_to: Paper)

      # Reviewer(s) get access to all submission tasks, except a few
      task_klasses = SUBMISSION_TASKS
      task_klasses -= [
        PlosBioTechCheck::ChangesForAuthorTask,
        PlosBilling::BillingTask,
        TahiStandardTasks::ReviewerRecommendationsTask
      ]
      task_klasses += [AdHocForReviewersTask]
      task_klasses.each do |klass|
        role.ensure_permission_exists(:view, applies_to: klass.name)
        role.ensure_permission_exists(:view_participants, applies_to: klass.name)
      end
      role.ensure_permission_exists(:edit, applies_to: AdHocForReviewersTask.name, states: Paper::REVIEWABLE_STATES)
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    # This role exists to give a reviewer the ability to edit their reviewer
    # report.
    Role.ensure_exists(Role::REVIEWER_REPORT_OWNER_ROLE, journal: @journal, participates_in: [Task]) do |role|
      role.ensure_permission_exists(
        :edit,
        applies_to: TahiStandardTasks::ReviewerReportTask,
        states: Paper::REVIEWABLE_STATES
      )

      role.ensure_permission_exists(:view, applies_to: TahiStandardTasks::ReviewerReportTask)
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::JOURNAL_SETUP_ROLE, journal: @journal) do |role|
      role.ensure_permission_exists(:create_card, applies_to: Journal)
      role.ensure_permission_exists(:edit, applies_to: Card)
      role.ensure_permission_exists(:view, applies_to: CardVersion)
      role.ensure_permission_exists(:administer, applies_to: Journal)
      role.ensure_permission_exists(:manage_users, applies_to: Journal)
    end

    Role.ensure_exists(Role::STAFF_ADMIN_ROLE, journal: @journal) do |role|
      # Journal
      role.ensure_permission_exists(:view_paper_tracker, applies_to: Journal)
      role.ensure_permission_exists(:remove_orcid, applies_to: Journal)
      role.ensure_permission_exists(:create_email_template, applies_to: Journal)

      # Paper
      role.ensure_permission_exists(:assign_roles, applies_to: Paper)
      role.ensure_permission_exists(:edit, applies_to: Paper)
      role.ensure_permission_exists(:edit_authors, applies_to: Paper)
      role.ensure_permission_exists(:edit_related_articles, applies_to: Paper)
      role.ensure_permission_exists(:edit_answers, applies_to: Paper)
      role.ensure_permission_exists(:manage_collaborators, applies_to: Paper)
      role.ensure_permission_exists(:manage_paper_authors, applies_to: Paper)
      role.ensure_permission_exists(:manage_workflow, applies_to: Paper)
      role.ensure_permission_exists(:perform_similarity_check, applies_to: Paper)
      role.ensure_permission_exists(:reactivate, applies_to: Paper, states: ['withdrawn'])
      role.ensure_permission_exists(:register_decision, applies_to: Paper)
      role.ensure_permission_exists(:rescind_decision, applies_to: Paper)
      role.ensure_permission_exists(:send_to_apex, applies_to: Paper)
      role.ensure_permission_exists(:search_academic_editors, applies_to: Paper)
      role.ensure_permission_exists(:search_admins, applies_to: Paper)
      role.ensure_permission_exists(:search_reviewers, applies_to: Paper)
      role.ensure_permission_exists(:submit, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: Paper)
      role.ensure_permission_exists(:view_decisions, applies_to: Paper)
      role.ensure_permission_exists(:view_user_role_eligibility_on_paper, applies_to: Paper)
      role.ensure_permission_exists(:withdraw, applies_to: Paper)
      role.ensure_permission_exists(:view_recent_activity, applies_to: Paper)

      # Tasks
      STANDARD_TASKS.each do |klass|
        role.ensure_permission_exists(:add_email_participants, applies_to: klass)
        role.ensure_permission_exists(:edit, applies_to: klass)
        role.ensure_permission_exists(:edit_due_date, applies_to: klass)
        role.ensure_permission_exists(:manage, applies_to: klass)
        role.ensure_permission_exists(:manage_invitations, applies_to: klass)
        role.ensure_permission_exists(:manage_participant, applies_to: klass)
        role.ensure_permission_exists(:manage_scheduled_events, applies_to: klass)
        role.ensure_permission_exists(:view_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:edit_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
        role.ensure_permission_exists(:view_participants, applies_to: klass)
      end

      role.ensure_permission_exists(:view, applies_to: Card)

      # The TitleAndAbstractTask is always editable, regardless of paper state.
      role.ensure_permission_exists(:edit, applies_to: TahiStandardTasks::TitleAndAbstractTask)

      # Discussions
      role.ensure_permission_exists(:be_at_mentioned, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:edit, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:manage_participant, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:reply, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:start_discussion, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: DiscussionTopic)

      # Users
      role.ensure_permission_exists(:manage_users, applies_to: Journal)
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::INTERNAL_EDITOR_ROLE, journal: @journal) do |role|
      # Journal
      role.ensure_permission_exists(:view_paper_tracker, applies_to: Journal)

      # Paper
      role.ensure_permission_exists(:assign_roles, applies_to: Paper)
      role.ensure_permission_exists(:edit, applies_to: Paper)
      role.ensure_permission_exists(:edit_authors, applies_to: Paper)
      role.ensure_permission_exists(:edit_related_articles, applies_to: Paper)
      role.ensure_permission_exists(:edit_answers, applies_to: Paper)
      role.ensure_permission_exists(:manage_collaborators, applies_to: Paper)
      role.ensure_permission_exists(:manage_paper_authors, applies_to: Paper)
      role.ensure_permission_exists(:manage_workflow, applies_to: Paper)
      role.ensure_permission_exists(:perform_similarity_check, applies_to: Paper)
      role.ensure_permission_exists(:reactivate, applies_to: Paper, states: ['withdrawn'])
      role.ensure_permission_exists(:register_decision, applies_to: Paper)
      role.ensure_permission_exists(:rescind_decision, applies_to: Paper)
      role.ensure_permission_exists(:search_academic_editors, applies_to: Paper)
      role.ensure_permission_exists(:search_admins, applies_to: Paper)
      role.ensure_permission_exists(:search_reviewers, applies_to: Paper)
      role.ensure_permission_exists(:send_to_apex, applies_to: Paper)
      role.ensure_permission_exists(:submit, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: Paper)
      role.ensure_permission_exists(:view_decisions, applies_to: Paper)
      role.ensure_permission_exists(:view_user_role_eligibility_on_paper, applies_to: Paper)
      role.ensure_permission_exists(:withdraw, applies_to: Paper)
      role.ensure_permission_exists(:view_recent_activity, applies_to: Paper)

      # Tasks
      STANDARD_TASKS.each do |klass|
        role.ensure_permission_exists(:add_email_participants, applies_to: klass)
        role.ensure_permission_exists(:edit, applies_to: klass)
        role.ensure_permission_exists(:edit_due_date, applies_to: klass)
        role.ensure_permission_exists(:manage, applies_to: klass)
        role.ensure_permission_exists(:manage_invitations, applies_to: klass)
        role.ensure_permission_exists(:manage_participant, applies_to: klass)
        role.ensure_permission_exists(:manage_scheduled_events, applies_to: klass)
        role.ensure_permission_exists(:view_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:edit_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
        role.ensure_permission_exists(:view_participants, applies_to: klass)
      end

      # The TitleAndAbstractTask is always editable, regardless of paper state.
      role.ensure_permission_exists(:edit, applies_to: TahiStandardTasks::TitleAndAbstractTask)

      # Discussions
      role.ensure_permission_exists(:be_at_mentioned, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:edit, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:manage_participant, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:reply, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:start_discussion, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::HANDLING_EDITOR_ROLE, journal: @journal, participates_in: [Paper]) do |role|
      # Paper
      role.ensure_permission_exists(:assign_roles, applies_to: Paper)
      role.ensure_permission_exists(:edit, applies_to: Paper, states: Paper::EDITABLE_STATES)
      role.ensure_permission_exists(:edit_authors, applies_to: Paper, states: Paper::EDITABLE_STATES)
      role.ensure_permission_exists(:edit_related_articles, applies_to: Paper)
      role.ensure_permission_exists(:manage_collaborators, applies_to: Paper)
      role.ensure_permission_exists(:manage_workflow, applies_to: Paper)
      role.ensure_permission_exists(:perform_similarity_check, applies_to: Paper)
      role.ensure_permission_exists(:register_decision, applies_to: Paper)
      role.ensure_permission_exists(:rescind_decision, applies_to: Paper)
      role.ensure_permission_exists(:search_academic_editors, applies_to: Paper)
      role.ensure_permission_exists(:search_admins, applies_to: Paper)
      role.ensure_permission_exists(:search_reviewers, applies_to: Paper)
      role.ensure_permission_exists(:submit, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: Paper)
      role.ensure_permission_exists(:view_decisions, applies_to: Paper)
      role.ensure_permission_exists(:view_user_role_eligibility_on_paper, applies_to: Paper)
      role.ensure_permission_exists(:view_recent_activity, applies_to: Paper)

      # Handling editors cannot view, edit, or otherwise do anything on the
      # BillingTask, the ChangesForAuthorTask, or the PaperEditorTast
      task_klasses = STANDARD_TASKS - [
        PlosBioTechCheck::ChangesForAuthorTask,
        TahiStandardTasks::PaperEditorTask
      ]
      task_klasses.each do |klass|
        role.ensure_permission_exists(:add_email_participants, applies_to: klass)
        role.ensure_permission_exists(:manage, applies_to: klass)
        role.ensure_permission_exists(:manage_participant, applies_to: klass)
        role.ensure_permission_exists(:view_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
        role.ensure_permission_exists(:view_participants, applies_to: klass)
      end

      # Handling Editors can edit _all_ tasks except for ReviewerReportTask(s).
      # Of those editable tasks all but the TitleAndAstractTask can only be
      # modified if the Paper itself is editable.
      editable_task_klasses = task_klasses -
        [TahiStandardTasks::ReviewerReportTask] -
        TahiStandardTasks::ReviewerReportTask.descendants -
        [TahiStandardTasks::TitleAndAbstractTask]
      editable_task_klasses.each do |klass|
        role.ensure_permission_exists(
          :edit,
          applies_to: klass,
          states: Paper::EDITABLE_STATES
        )
      end

      # The TitleAndAbstractTask is always editable, regardless of paper state.
      role.ensure_permission_exists(:edit, applies_to: TahiStandardTasks::TitleAndAbstractTask)

      # Discussions
      role.ensure_permission_exists(:edit, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:manage_participant, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:reply, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:start_discussion, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:be_at_mentioned, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::PRODUCTION_STAFF_ROLE, journal: @journal) do |role|
      # Journal
      role.ensure_permission_exists(:view_paper_tracker, applies_to: Journal)
      role.ensure_permission_exists(:remove_orcid, applies_to: Journal)

      # Paper
      role.ensure_permission_exists(:assign_roles, applies_to: Paper)
      role.ensure_permission_exists(:edit, applies_to: Paper)
      role.ensure_permission_exists(:edit_authors, applies_to: Paper)
      role.ensure_permission_exists(:edit_related_articles, applies_to: Paper)
      role.ensure_permission_exists(:manage_collaborators, applies_to: Paper)
      role.ensure_permission_exists(:manage_workflow, applies_to: Paper)
      role.ensure_permission_exists(:perform_similarity_check, applies_to: Paper)
      role.ensure_permission_exists(:reactivate, applies_to: Paper, states: ['withdrawn'])
      role.ensure_permission_exists(:register_decision, applies_to: Paper)
      role.ensure_permission_exists(:rescind_decision, applies_to: Paper)
      role.ensure_permission_exists(:search_academic_editors, applies_to: Paper)
      role.ensure_permission_exists(:search_admins, applies_to: Paper)
      role.ensure_permission_exists(:search_reviewers, applies_to: Paper)
      role.ensure_permission_exists(:send_to_apex, applies_to: Paper)
      role.ensure_permission_exists(:submit, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: Paper)
      role.ensure_permission_exists(:view_decisions, applies_to: Paper)
      role.ensure_permission_exists(:view_user_role_eligibility_on_paper, applies_to: Paper)
      role.ensure_permission_exists(:withdraw, applies_to: Paper)
      role.ensure_permission_exists(:view_recent_activity, applies_to: Paper)

      # Tasks
      STANDARD_TASKS.each do |klass|
        role.ensure_permission_exists(:add_email_participants, applies_to: klass)
        role.ensure_permission_exists(:edit, applies_to: klass)
        role.ensure_permission_exists(:manage, applies_to: klass)
        role.ensure_permission_exists(:manage_invitations, applies_to: klass)
        role.ensure_permission_exists(:manage_participant, applies_to: klass)
        role.ensure_permission_exists(:manage_scheduled_events, applies_to: klass)
        role.ensure_permission_exists(:view_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:edit_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
        role.ensure_permission_exists(:view_participants, applies_to: klass)
      end

      # Discussions
      role.ensure_permission_exists(:be_at_mentioned, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:edit, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:manage_participant, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:reply, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:start_discussion, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: DiscussionTopic)

      # Users
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::PUBLISHING_SERVICES_ROLE, journal: @journal) do |role|
      # Journals
      role.ensure_permission_exists(:view_paper_tracker, applies_to: Journal)
      role.ensure_permission_exists(:remove_orcid, applies_to: Journal)

      # Paper
      role.ensure_permission_exists(:assign_roles, applies_to: Paper)
      role.ensure_permission_exists(:edit, applies_to: Paper)
      role.ensure_permission_exists(:edit_authors, applies_to: Paper)
      role.ensure_permission_exists(:edit_related_articles, applies_to: Paper)
      role.ensure_permission_exists(:edit_answers, applies_to: Paper)
      role.ensure_permission_exists(:manage_collaborators, applies_to: Paper)
      role.ensure_permission_exists(:manage_paper_authors, applies_to: Paper)
      role.ensure_permission_exists(:manage_workflow, applies_to: Paper)
      role.ensure_permission_exists(:perform_similarity_check, applies_to: Paper)
      role.ensure_permission_exists(:reactivate, applies_to: Paper, states: ['withdrawn'])
      role.ensure_permission_exists(:register_decision, applies_to: Paper)
      role.ensure_permission_exists(:rescind_decision, applies_to: Paper)
      role.ensure_permission_exists(:search_academic_editors, applies_to: Paper)
      role.ensure_permission_exists(:search_admins, applies_to: Paper)
      role.ensure_permission_exists(:search_reviewers, applies_to: Paper)
      role.ensure_permission_exists(:send_to_apex, applies_to: Paper)
      role.ensure_permission_exists(:submit, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: Paper)
      role.ensure_permission_exists(:view_decisions, applies_to: Paper)
      role.ensure_permission_exists(:view_user_role_eligibility_on_paper, applies_to: Paper)
      role.ensure_permission_exists(:withdraw, applies_to: Paper)
      role.ensure_permission_exists(:view_recent_activity, applies_to: Paper)

      # Tasks
      STANDARD_TASKS.each do |klass|
        role.ensure_permission_exists(:add_email_participants, applies_to: klass)
        role.ensure_permission_exists(:edit, applies_to: klass)
        role.ensure_permission_exists(:edit_due_date, applies_to: klass)
        role.ensure_permission_exists(:manage, applies_to: klass)
        role.ensure_permission_exists(:manage_invitations, applies_to: klass)
        role.ensure_permission_exists(:manage_participant, applies_to: klass)
        role.ensure_permission_exists(:manage_scheduled_events, applies_to: klass)
        role.ensure_permission_exists(:view_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:edit_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
        role.ensure_permission_exists(:view_participants, applies_to: klass)
      end

      # Discussions
      role.ensure_permission_exists(:be_at_mentioned, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:edit, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:manage_participant, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:start_discussion, applies_to: Paper)
      role.ensure_permission_exists(:reply, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:view, applies_to: DiscussionTopic)

      # Users
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::TASK_PARTICIPANT_ROLE, journal: @journal, participates_in: [Task]) do |role|
      role.ensure_permission_exists(:view, applies_to: Paper)

      role.ensure_permission_exists(:edit, applies_to: Task, states: Paper::EDITABLE_STATES)
      role.ensure_permission_exists(:manage_participant, applies_to: Task)
      role.ensure_permission_exists(:view, applies_to: Task)
      role.ensure_permission_exists(:view_participants, applies_to: Task)
      role.ensure_permission_exists(:view, applies_to: CardVersion)
    end

    Role.ensure_exists(Role::ACADEMIC_EDITOR_ROLE,
                       journal: @journal,
                       participates_in: [Paper]) do |role|
      role.ensure_permission_exists(:view, applies_to: Paper)

      task_klasses = SUBMISSION_TASKS

      # AEs cannot view Billing task, Register Decision tasks, or
      # Changes For Author tasks. However, AEs can view all
      # ReviewerReportTask(s) and its descendants, but cannot edit them.
      task_klasses -= [
        PlosBioTechCheck::ChangesForAuthorTask,
        PlosBilling::BillingTask,
        TahiStandardTasks::RegisterDecisionTask
      ]
      task_klasses += [TahiStandardTasks::ReviewerReportTask]
      task_klasses.each do |klass|
        role.ensure_permission_exists(:view, applies_to: klass)
      end

      AdHocForEditorsTask.tap do |klass|
        role.ensure_permission_exists(:edit, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
      end
    end

    Role.ensure_exists(Role::DISCUSSION_PARTICIPANT, journal: @journal, participates_in: [Paper]) do |role|
      role.ensure_permission_exists(:be_at_mentioned, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:reply, applies_to: DiscussionTopic)
      role.ensure_permission_exists(:view, applies_to: DiscussionTopic)
    end

    Role.ensure_exists(Role::FREELANCE_EDITOR_ROLE, journal: @journal)

    Role.ensure_exists(Role::BILLING_ROLE, journal: @journal, participates_in: [Task]) do |role|
      (STANDARD_TASKS + [PlosBilling::BillingTask]).each do |klass|
        role.ensure_permission_exists(:view_discussion_footer, applies_to: klass)
        role.ensure_permission_exists(:view, applies_to: klass)
        role.ensure_permission_exists(:view_participants, applies_to: klass)
      end

      role.ensure_permission_exists(:edit, applies_to: PlosBilling::BillingTask)
      role.ensure_permission_exists(:view_paper_tracker, applies_to: Journal)
      role.ensure_permission_exists(:view, applies_to: Paper)
      role.ensure_permission_exists(:view, applies_to: CardVersion)
      role.ensure_permission_exists(:view_recent_activity, applies_to: Paper)
    end
  end

  def seed_letter_templates
    seed_ae_invite
    seed_register_decision_reject
    seed_register_decision_revise_or_accept
    seed_reviewer_report
    seed_preprint_decision
    seed_paper_submit
    seed_preprint_sendbacks
  end

  # rubocop:disable Style/GuardClause
  def seed_ae_invite
    ident = 'academic-editor-invite'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Academic Editor Invite', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Invitation'
        lt.subject = 'You\'ve been invited as an editor for the manuscript, {{ manuscript.title }}'
        lt.body = <<-TEXT.strip_heredoc
        {% if  invitee %}
        <p>Dear Dr.{{ invitee.full_name }},</p>
        {% endif %}
        <p>I am writing to seek your advice as the academic editor on a manuscript entitled '{{ manuscript.title }}'. The corresponding author is {{author.full_name}}, and the manuscript is under consideration at {{ journal.name }}.</p>
        <p>We would be very grateful if you could let us know whether or not you are able to take on this assignment within 24 hours, so that we know whether to await your comments, or if we need to approach someone else. To accept or decline the assignment via our submission system, please use the link below. If you are available to help and have no conflicts of interest, you also can view the entire manuscript via this link.</p>
        <p>If you do take this assignment, and think that this work is not suitable for further consideration by {{ journal.name }}, please tell us if it would be more appropriate for another journal.</p>
        <p>I have appended further information, including a copy of the abstract and full list of authors below.</p>
        <p>My colleagues and I are grateful for your support and advice. Please don't hesitate to contact me should you have any questions.</p>
        <p>Kind regards,</p>
        <p>{{ inviter.full_name }}</p>
        <p>{{ journal.name }}</p>
        <p>***************** CONFIDENTIAL *****************</p>
        <p>{{ manuscript.paper_type }}</p>
        <p>Manuscript Title:<br>
        {{ manuscript.title }}</p>
        <p>Authors:<br>
        {% for author in manuscript.authors %}
        {{ forloop.index }}. {{ author.last_name }}, {{ author.first_name }}<br>
        {% endfor %}</p>
        <p>Abstract:<br>
        {{ manuscript.abstract | default: 'Abstract is not available' }}</p>
        <p>To view this manuscript, please use the link presented above in the body of the e-mail.</p>
        <p>You will be directed to your dashboard in Aperta, where you will see your invitation. Selecting "yes" confirms your assignment as Academic Editor. Selecting "yes" to accept this assignment will allow you to access the full submission from the Dashboard link in your main menu.</p>
        TEXT
        lt.save!
      end
    end
  end

  # rubocop:disable Style/GuardClause
  def seed_preprint_sendbacks
    ident = 'preprint-sendbacks'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Sendback Reasons', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Tech Check'
        lt.subject = 'Manuscript Sendback Reasons'
        lt.to = '{{author.email}}'
        lt.body = <<-TEXT.strip_heredoc
        {{intro}}
        <ol>
          {% for reason in sendback_reasons %}
            <li>{{reason.value}}</li>
          {% endfor %}
        </ol>
        {{footer}}
        TEXT

        lt.save!
      end
    end

    ident = 'changes-for-author'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Changes For Author', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Tech Check'
        lt.subject = 'Manuscript Sendback Reasons'
        lt.to = '{{author.email}}'
        lt.body = <<-TEXT.strip_heredoc
        <ol>
          {% for reason in paperwide_sendback_reasons %}
            <li>{{reason.value}}</li>
          {% endfor %}
        </ol>
        TEXT

        lt.save!
      end
    end
  end

  def seed_register_decision_reject
    ident = 'editor-decision-reject-after-review'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Editor Decision - Reject After Review', category: 'reject', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Decision'
        lt.subject = 'Your {{ journal.name }} submission'
        lt.to = author_emails
        lt.body = <<-TEXT.strip_heredoc
          <p>***EDIT THIS LETTER BEFORE SENDING****</p>
          #{greeting}
          <p>Thank you very much for submitting your manuscript "{{ manuscript.title }}" for review by {{ journal.name }}. As with all papers reviewed by the journal, yours was assessed and discussed by the {{ journal.name }} editors. In this case, your article was also assessed by an Academic Editor with relevant expertise and several independent reviewers. Based on the reviews, I regret that we will not be able to accept this manuscript for publication in the journal.</p>
          <p>The reviews are attached, and we hope they may help you should you decide to revise the manuscript for submission elsewhere. I am sorry that we cannot be more positive on this occasion.</p>
          <p>I hope you appreciate the reasons for this decision and will consider {{ journal.name }} for other submissions in the future. Thank you for your support of open access publishing.</p>
          <p>Sincerely,<br/>
            #{signature}
          </p>
          #{reviews}
        TEXT

        lt.save!
      end
    end
  end

  def seed_register_decision_revise_or_accept
    ident = 'ra-major-revision'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'RA Major Revision', category: 'major_revision', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Decision'
        lt.subject = 'A decision has been registered on the manuscript, "{{ manuscript.title }}"'
        lt.to = author_emails
        lt.body = <<-TEXT.strip_heredoc
          <p>**choose appropriate first paragraph; attach prod reqs PDF - DELETE THIS***</p>
          #{greeting}
          <p>***EITHER****</p><p>Thank you very much for submitting your manuscript “{{ manuscript.title }}” for consideration at {{ journal.name }}. Your manuscript has been evaluated by the {{ journal.name }} editorial staff, by an Academic Editor with relevant expertise, and by several independent reviewers.</p>
          <p>****OR (if previous OPEN REJECT)****</p><p>Thank you very much for submitting a revised version of your manuscript \"{{ manuscript.title }}\" for consideration at {{ journal.name }}. This revised version of your manuscript has been evaluated by the {{ journal.name }} editorial staff, an Academic Editor and reviewers.</p>
          <p>****</p>
          <p>In light of the reviews, we will not be able to accept the current version of the manuscript, but we would welcome resubmission of a much-revised version that takes into account the reviewers' comments. We cannot make any decision about publication until we have seen the revised manuscript and your response to the reviewers' comments. Your revised manuscript is also likely to be sent for further evaluation by the reviewers.</p>
          <p>Your revisions should address the specific points made by each reviewer. Please also submit a cover letter and a point-by-point response to all of the reviewers' comments that indicates the changes you have made to the manuscript. You should also cite any additional relevant literature that has been published since the original submission and mention any additional citations in your response.</p>
          <p>Upon resubmission, the editors will assess the advance your revised manuscript represents over work published prior to its resubmission in reaching a decision regarding further consideration. The editors also will assess the revisions you have made and decide whether to consult further with an Academic Editor. If the editors and Academic Editor feel that the revised manuscript remains appropriate for the journal and that the revisions are sufficient to warrant further consideration, we generally will send the manuscript for re-review. We aim to consult the same Academic Editor and reviewers for revised manuscripts but may consult others if needed.</p>
          <p>We expect to receive your revised manuscript within two months. Please email us ({{ journal.staff_email }}) to discuss this if you have any questions or concerns, or would like to request an extension.</p>
          <p>At this stage, your manuscript remains formally under active consideration at our journal. Please note that unless we receive the revised manuscript within this timeframe, your submission may be closed and the manuscript would no longer be ‘under consideration’ at {{ journal.name }}. We will of course be in touch before this action is taken. Please rest assured that this is merely an administrative step - you may still submit your revised submission after your file is closed, but will need to do so as a new submission, referencing the previous tracking number.</p>
          <p>Please notify us by email if you do not wish to revise your manuscript for {{ journal.name }} and instead wish to pursue publication elsewhere, so that we may end consideration of the manuscript at {{ journal.name }}.</p>
          <p>If you do still intend to submit a revised version of your manuscript, please log in.  On the ‘Your Manuscripts’ page, click the title of your manuscript to access and edit your submission.</p>
          <p>Thank you again for your submission to our journal. We hope that our editorial process has been constructive thus far, and we welcome your feedback at any time. Please don't hesitate to contact us if you have any questions or comments.</p>
          <p>Sincerely,<br/>
            #{signature}
          </p>
          <br/>
          #{reviews}
        TEXT

        lt.save!
      end
    end

    ident = 'ra-minor-revision'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'RA Minor Revision', category: 'minor_revision', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Decision'
        lt.subject = 'Your {{ journal.name }} submission'
        lt.to = author_emails
        lt.body = <<-TEXT.strip_heredoc
          <p>** CHOOSE BETWEEN NUMBERED PARAGRAPHS BELOW **</p>
          <p>** REMOVE THIS TEXT BEFORE SENDING **</p>
          #{greeting}
          <p>[1] <br />Thank you very much for submitting your manuscript "{{ manuscript.title }}" for review by {{ journal.name }}. As with all papers reviewed by the journal, yours was seen by the journal's editorial staff as well as by an Academic Editor with relevant expertise. In this case, your article was also evaluated by independent reviewers. The reviewers appreciated the attention to an important topic. Based on the reviews, we will probably accept this manuscript for publication, providing that you are willing and able to modify the manuscript according to the review recommendations.</p>
          <p>[2]<br />Thank you for submitting your revised manuscript entitled "{{ manuscript.title }}" for publication in {{ journal.name }}. I have now obtained advice from the original reviewers and have discussed their comments with the Academic Editor.</p>
          <p>******* DELETE AS APPROPRIATE &ndash; TWO LARGE SECTIONS TO CHOOSE BETWEEN</p>
          <p>EITHER [3]:<br />Based on the reviews, we will probably accept this manuscript for publication, assuming that you are willing and able to modify the manuscript to address the remaining concerns raised by the reviewers.</p>
          <p>***Insert Editorial Requirements and INCLUDE DATA REQUIREMENTS AS NECESSARY***</p>
          <p>We expect to receive your revised manuscript within two weeks. Your revisions should address the specific points made by each reviewer. In addition to the remaining revisions and before we will be able to formally accept your manuscript and consider it "in press", we also need to ensure that your article conforms to our guidelines. A member of our team will be in touch shortly with a set of requests regarding the manuscript files. As we can&rsquo;t proceed until these requirements are met, your swift response will help prevent delays to publication.</p>
          <p>OR [4]: <br />We&rsquo;re delighted to let you know that we're now editorially satisfied with your manuscript, however before we can formally accept your manuscript and consider it "in press", we also need to ensure that your article conforms to our guidelines. A member of our team will be in touch shortly with a set of requests regarding the manuscript files. As we can&rsquo;t proceed until these requirements are met, your swift response will help prevent delays to publication. <br />******* <br /><br />Upon acceptance of your article, your final files will be copyedited and typeset into the final PDF. While you will have an opportunity to review these files as proofs, the journal will only permit corrections to spelling or significant scientific errors. Therefore, please take this final revision time to assess and make any remaining major changes to your manuscript.</p>
          <p>To submit your revision, please log in. Click the title of your manuscript from the Your Manuscripts page to access and edit your submission. Your revised submission must include a cover letter, and a Response to Reviewers that provides a detailed response to the reviewers' comments (if applicable) and indication of any changes that you have made to the manuscript.</p>
          <p>Please do not hesitate to contact me should you have any questions.</p>
          <p>Sincerely,<br/>
            #{signature}
          </p>
          #{reviews}
        TEXT

        lt.save!
      end
    end

    ident = 'ra-accept'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'RA Accept', category: 'accept', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Decision'
        lt.subject = 'Your {{ journal.name }} submission'
        lt.to = author_emails
        lt.body = <<-TEXT.strip_heredoc
          <p>***EDIT THIS LETTER BEFORE SENDING****</p>
          #{greeting}
          <p>On behalf of my colleagues and the Academic Editor, [*INSERT AE'S NAME*], I am pleased to inform you that we will be delighted to publish your manuscript in {{ journal.name }}.</p>
          <p>Please note that since your article will appear in the magazine section of the journal you will not be charged for publication.</p>
          <p>The files will now enter our production system. In one-two weeks' time, you should receive a copyedited version of the manuscript, along with your figures for a final review. You will be given two business days to review and approve the copyedit. Then, within a week, you will receive a PDF proof of your typeset article. You will have two days to review the PDF and make any final corrections. If there is a chance that you'll be unavailable during the copy editing/proof review period, please provide us with contact details of one of the other authors whom you nominate to handle these stages on your behalf. This will ensure that any requested corrections reach the production department in time for publication.</p>
          <p>Please don't hesitate to contact me should you have any questions.</p>
          <p>Kind regards, <br />
            [*INSERT NAME*]<br />
            Publications Assistant<br />
            {{ journal.name }}
          </p>
          <p>On Behalf of<br />
            [*HANDLING EDITOR*]<br />
            [*HANDLING EDITOR POSITION*]<br />
            {{ journal.name }}
          </p>
        TEXT

        lt.save!
      end
    end
  end

  def seed_reviewer_report
    ident = 'review-reminder-before-due'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Review Reminder - Before Due', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Reviewer Report'
        lt.subject = 'Your review for {{ journal.name }} is due soon'
        lt.body = <<-TEXT.strip_heredoc
          <p>Dear Dr. {{ reviewer.last_name }}</p>
          <p>Thank you again for agreeing to review “{{ manuscript.title }}” for {{ journal.name }}. This is a brief reminder that we hope to receive your review comments on the manuscript by {{ review.due_at }}. Please let us know as soon as possible, by return email, if your review will be delayed.</p>
          <p>To view the manuscript and submit your review, please log in to Aperta via the green button below.</p>
          <p>We are grateful for your continued support of {{ journal.name }}. Please do not hesitate to contact the journal office if you have questions or require assistance.</p>
        TEXT

        lt.save!
      end
    end

    ident = 'review-reminder-first-late'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Review Reminder - First Late', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Reviewer Report'
        lt.subject = 'Late Review for {{ journal.name }}'
        lt.body = <<-TEXT.strip_heredoc
          <p>Dear Dr. {{ reviewer.last_name }}</p>
          <p>This is a reminder that your review of the manuscript “{{ manuscript.title }}” was due to be received by  {{ review.due_at }}.</p>
          <p>As your review was due two days ago, we would be grateful if you could provide us with your comments as soon as possible. If you are busy and unable to complete your review in this timeframe, please let us know by return email so that we may plan accordingly.</p>
          <p>To view the manuscript and submit your review, please log in to Aperta via the green button below.</p>
          <p>We are grateful for your continued support of {{ journal.name }}. Please do not hesitate to contact the journal office if you have questions or require assistance.</p>
        TEXT

        lt.save!
      end
    end

    ident = 'review-reminder-second-late'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Review Reminder - Second Late', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Reviewer Report'
        lt.subject = 'Reminder of Late Review for {{ journal.name }}'
        lt.body = <<-TEXT.strip_heredoc
          <p>Dear Dr. {{ reviewer.last_name }}</p>
          <p>This is a reminder that your review of the manuscript “{{ manuscript.title }}” was expected by the agreed due date, {{ review.due_at }}. At this stage we urgently need the review in order to proceed with the editorial process.</p>
          <p>We would appreciate it if you can submit your review as soon as possible so that we can move this manuscript to a decision for the authors. If you need assistance or are experiencing delays, please let us know by return email.</p>
          <p>To view the manuscript and submit your review, please log in to Aperta via the green button below.</p>
          <p>We are grateful for your continued support of {{ journal.name }}. Please do not hesitate to contact the journal office if you have questions or require assistance.</p>
        TEXT

        lt.save!
      end
    end

    ident = 'reviewer-appreciation'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Reviewer Appreciation', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Reviewer Report'
        lt.subject = 'Thank you for reviewing for {{ journal.name }}'
        lt.body = <<-TEXT.strip_heredoc
          <p>Dear {{ reviewer.first_name }} {{ reviewer.last_name }},</p>
          <p>Thank you for taking the time to review the manuscript “{{ manuscript.title }}”, for {{ journal.name }}.
          We greatly appreciate your assistance with the review process, especially given the many competing demands on your time.</p>
          <p>Thank you for your continued support of {{ journal.name }}, we look forward to working with you again in the future.
          If you have any questions or feedback, please do not hesitate to contact us at {{ journal.staff_email }}.</p>
        TEXT

        lt.save!
      end
    end

    ident = 'reviewer-invite'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Reviewer Invite', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Invitation'
        lt.subject = 'You have been invited as a reviewer for the manuscript, "{{ manuscript.title }}"'
        lt.body = <<-TEXT.strip_heredoc
            {% if  invitee %}
            <p>Dear {{  invitee.full_name }},</p>
            {% endif %}
            <p>You've been invited as a Reviewer on "{{ manuscript.title }}", for {{ journal.name }}.</p>
            <p>The abstract is included below. We would ideally like to have reviews returned to us within {{ invitation.due_in_days }} days. If you require additional time, please do let us know so that we may plan accordingly.</p>
            <p>Please only accept this invitation if you have no conflicts of interest. If in doubt, please feel free to contact us for advice. If you are unable to review this manuscript, we would appreciate suggestions of other potential reviewers.</p>
            <p>We look forward to hearing from you.</p>
            <p>Sincerely,</p>
            <p>{{ journal.name }} Team</p>
            <p>***************** CONFIDENTIAL *****************</p>
            <p>{{ manuscript.paper_type }}</p>
            <p>Manuscript Title:<br>
            {{ manuscript.title }}</p>
            <p>Authors:<br>
            {% for author in manuscript.authors %}
            {{ forloop.index }}. {{ author.last_name }}, {{ author.first_name }}<br>
            {% endfor %}</p>
            <p>Abstract:<br>
            {{ manuscript.abstract | default: 'Abstract is not available' }}</p>
          TEXT

        lt.save!
      end
    end
    ident = 'reviewer-welcome'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Reviewer Welcome', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Reviewer Report'
        lt.to = '{{ reviewer.email }}'
        lt.subject = 'Thank you for agreeing to review for {{ journal.name }}'
        lt.body = <<-TEXT.strip_heredoc
          <h1>Thank you for agreeing to review for {{ journal.name }}</h1>
          <p>Hello {{ reviewer.full_name }},</p>
          <p>Thank you very much for agreeing to review the manuscript "{{ manuscript.title }}" for {{ journal.name }}.</p>
          <p>In the interest of returning timely decisions to the authors, please return your review by {{ review.due_at_with_minutes }}. Please do let us know if you wish to request additional time to review this manuscript, so that we may plan accordingly.</p>
        TEXT

        lt.save!
      end
    end
    ident = 'reviewer-accepted'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Reviewer Accepted', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Invitation'
        lt.to = '{{ inviter.email }}'
        lt.subject = 'Reviewer invitation was accepted on the manuscript, "{{ manuscript.title }}"'
        lt.body = <<-TEXT.strip_heredoc
          <p>Hello {{ inviter.full_name }}</p>
          <p>{{ invitee_name_or_email }} has accepted your invitation to review the Manuscript: "{{ manuscript.title }}".</p>
        TEXT

        lt.save!
      end
    end
    ident = 'reviewer-declined'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Reviewer Declined', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Invitation'
        lt.to = '{{ inviter.email }}'
        lt.subject = 'Reviewer invitation was declined on the manuscript, "{{ manuscript.title }}"'
        lt.body = <<-TEXT.strip_heredoc
          <p>Hello {{ inviter.full_name }}</p>
          <p>{{ invitee_name_or_email }} has declined your invitation to review the Manuscript: "{{ manuscript.title }}".</p>
          <p class="decline_reason"><strong>Reason:</strong> {{ invitation.decline_reason }}</p>
          <p class="reviewer_suggestions"><strong>Reviewer Suggestions:</strong> {{ invitation.reviewer_suggestions }}</p>
        TEXT

        lt.save!
      end
    end
  end

  def seed_preprint_decision
    ident = 'preprint-accept'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Preprint Accept', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Preprint Decision'
        lt.subject = 'Manuscript Accepted for pre-print'
        lt.to = '{{manuscript.creator.email}}'
        lt.body = <<-TEXT.strip_heredoc
          <p>Dear Dr. {{manuscript.creator.last_name}},</p>
          <p>Your {{journal.name}} manuscript, '{{manuscript.title}}', has been approved for pre-print publication. Because you have opted in to this opportunity, your manuscript has been forwarded for pre-print posting. You will receive another message with publication details when the article has posted.</p>
          <p>Please note this decision is not related to the decision to publish your manuscript in {{journal.name}}. As your manuscript is evaluated for publication you will receive additional communications.</p>
          <p>Kind regards,</p>
          <p>Publication Team</p>
        TEXT

        lt.save!
      end
    end

    ident = 'preprint-reject'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Preprint Reject', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Preprint Decision'
        lt.subject = 'Manuscript Declined for pre-print'
        lt.to = '{{manuscript.creator.email}}'
        lt.body = <<-TEXT.strip_heredoc
          <p>Dear Dr. {{manuscript.creator.last_name}},</p>
          <p>Your {{journal.name}} manuscript, '{{manuscript.title}}', has been declined for pre-print publication.</p>
          <p>Please note this decision is not related to the decision to publish your manuscript in {{journal.name}}. As your manuscript is evaluated for publication you will receive additional communications.</p>
          <p>Kind regards,</p>
          <p>Publication Team</p>
        TEXT

        lt.save!
      end
    end
  end

  def seed_paper_submit
    ident = 'notify-initial-submission'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Notify Initial Submission', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Manuscript'
        lt.subject = "Thank you for submitting to {{ journal.name }}"
        lt.to = '{{ manuscript.creator.email }}'
        lt.body = <<-TEXT.strip_heredoc
          <h1>Thank you for submitting your manuscript, {{ manuscript.title }}, to {{ journal.name }}. Our staff will be in touch with next steps.</h1>
          <p>Dear {{ manuscript.creator.full_name }},</p>
          <p>Thank you for your submission to {{ journal.name }}, which will now be assessed by the editors to determine whether your manuscript meets the criteria for peer review. We may seek advice from an Academic Editor with relevant expertise.</p>
          <p>If our initial evaluation is positive, we will contact you to request statements relating to ethical approval, funding, data and competing interests ahead of initiating peer review. This additional information is required to satisfy the journal's policies and will be made available to editors and reviewers. If you anticipate that you will be unavailable during the next week or two, please provide us with an additional person of contact by return email.</p>
          {% if manuscript.preprint_opted_in %}
            <p>Thank you for choosing to share your manuscript as a preprint. Our staff will review your submission and contact you if your article complies with our preprint policy. Please refer to the editorial staff of your journal to discuss any concerns.</p>
          {% endif %}
          {% if manuscript.preprint_opted_out %}
            <p>You choose not to share your manuscript as a preprint. If you wish to revisit that decision please contact the editorial staff of your journal.</p>
          {% endif %}
        TEXT

        lt.save!
      end
    end

    ident = 'notify-submission'
    unless LetterTemplate.exists?(journal: @journal, ident: ident)
      LetterTemplate.where(name: 'Notify Submission', journal: @journal).first_or_initialize.tap do |lt|
        lt.ident = ident
        lt.scenario = 'Manuscript'
        lt.subject = "Thank you for submitting your manuscript to {{ journal.name }}"
        lt.to = '{{ manuscript.creator.email }}'
        lt.body = <<-TEXT.strip_heredoc
          <h1>Thank you for submitting your manuscript, {{ manuscript.title }}, to {{ journal.name }}. Our staff will be in touch with next steps.</h1>
          <p>Hello {{ manuscript.creator.full_name }},</p>
          <p>Thank you for submitting your manuscript, {{ manuscript.title }}, to {{ journal.name }}. Your submission is complete, and our staff will be in touch with next steps.</p>
          {% if manuscript.preprint_opted_in %}
            <p>Thank you for choosing to share your manuscript as a preprint. Our staff will review your submission and contact you if your article complies with our preprint policy. Please refer to the editorial staff of your journal to discuss any concerns.</p>
          {% endif %}
          {% if manuscript.preprint_opted_out %}
            <p>You choose not to share your manuscript as a preprint. If you wish to revisit that decision please contact the editorial staff of your journal.</p>
          {% endif %}
        TEXT

        lt.save!
      end
    end
  end

  # rubocop:enable Style/GuardClause

  def author_emails
    '{{ manuscript.corresponding_authors | map: "email" | join: "," }}'
  end

  def greeting
    <<-TEXT.strip_heredoc
      Dear {% for author in manuscript.corresponding_authors %}Dr. {{author.last_name}},{% endfor %}
    TEXT
  end

  def signature
    <<-TEXT.strip_heredoc
      {% if manuscript.editor %}
        {{ manuscript.editor.first_name }} {{ manuscript.editor.last_name }}<br/>
        {% if manuscript.editor.title %}
          {{ manuscript.editor.title }}<br/>
        {% endif %}
      {% else %}
        [EDITOR NAME]<br/>
        [EDITOR TITLE]<br/>
      {% endif %}
      {{ journal.name }}
    TEXT
  end

  def reviews
    <<-TEXT.strip_heredoc
      {% if reviews != empty %}
        <p>------------------------------------------------------------------------</p>
        <p>Reviewer Notes:</p>
        {% for review in reviews %}
          {%- if review.status == 'completed' -%}
            ----------<br/>
            <p>Reviewer {{ review.reviewer_number }} {{ review.reviewer_name }}</p>
            {%- for answer in review.rendered_answers -%}
            <p>
              {{ answer.value }}
            </p>
            {%- endfor -%}
          {% endif %}
        {% endfor %}
      {% endif %}
    TEXT
  end
end
