namespace :data do
  namespace :migrate do
    namespace :reviewers do
      desc <<-DESC
        APERTA-9054: This removes reviewers as participants on their Reviewer Report Task which
        ensures that reviewers are not granted permissions to the discussion panel and they
        only have the permissions appropriate to their role.
      DESC
      task remove_participant_roles: :environment do
        relevant_tasks = ['TahiStandardTasks::ReviewerReportTask', 'TahiStandardTasks::FrontMatterReviewerReportTask']
        set_of_reviewer_report_ids = Task.where(type: relevant_tasks).pluck(:id)
        deletion_count = 0
        user_count = 0

        User.joins(:roles).where(roles: {name: 'Reviewer Report Owner'}).find_each do |reviewer|
          user_count += 1
          reviewer.participations.where(assigned_to_id: set_of_reviewer_report_ids).each do |assignment|
            STDOUT.puts("Deleting Reviewer Report Owner #{reviewer.id}'s participation assignment #{assignment.id} for paper #{assignment.assigned_to.paper.short_doi}...")
            assignment.destroy!
            deletion_count += 1
          end
        end
        STDOUT.puts("-------------------------------------")
        STDOUT.puts("Deleted #{deletion_count} participation assignments")
      end

      desc <<-DESC
        APERTA-9054: This makes all reviewers participants on their Reviewer Report Task
      DESC
      task add_back_participant_roles: :environment do
        # THIS MAY ADD BACK REVIEWERS AS PARTICIPANTS WHO WERE PREVIOUSLY REMOVED AS PARTICIPANTS
        relevant_tasks = ['TahiStandardTasks::ReviewerReportTask', 'TahiStandardTasks::FrontMatterReviewerReportTask']
        set_of_reviewer_report_ids = Task.where(type: relevant_tasks).pluck(:id)
        set_of_reviewer_report_owner_role_ids = Role.where(name: 'Reviewer Report Owner').pluck(:id)
        added_count = 0
        user_count = 0

        Role.where(name: 'Reviewer Report Owner').each do |owner_role|
          user_count += 1
          owner_role.users.each do |reviewer_report_owner|
            reviewer_report_owner.assignments.where(assigned_to_type: 'Task', assigned_to_id: set_of_reviewer_report_ids).where(role_id: set_of_reviewer_report_owner_role_ids).each do |report_owner_assignment|
                                                task = report_owner_assignment.assigned_to
                                                reviewer_report_owner = report_owner_assignment.user
                                                STDOUT.puts("Adding back Reviewer Report Owner #{reviewer_report_owner.id}'s participation...")
                                                participation = ParticipationFactory.create(task: task, assignee: reviewer_report_owner, assigner: reviewer_report_owner, notify: false)
                                                if participation.present?
                                                  added_count += 1
                                                  STDOUT.puts("Created participation for Reviewer Report Owner #{reviewer_report_owner.id} for paper #{task.paper.id}")
                                                else
                                                  if task.participants.include? reviewer_report_owner
                                                    participation = task.participations.find_by(user: reviewer_report_owner)
                                                    STDOUT.puts("Already have participation #{participation.id} for Reviewer Report Owner #{reviewer_report_owner.id}")
                                                  else
                                                    STDERR.puts("Failed to create participation for Reviewer Report Owner #{reviewer_report_owner.id}")
                                                    fail "Error with creating participation for Reviewer Report Owner #{reviewer_report_owner.id}"
                                                  end
                                                end
                                             end
          STDOUT.puts("-------------------------------------")
          STDOUT.puts("Added #{added_count} participations for #{user_count} Reviewer Report Owners")
          end
        end
      end
    end
  end
end
