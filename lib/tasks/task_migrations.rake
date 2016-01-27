namespace :data do
  desc 'Update or Create JournalTaskType and Tasks records for all journals'
  task update_journal_task_types: :environment do
    Rails.application.config.eager_load_namespaces.each(&:eager_load!)
    Rails.logger.info 'Updating JournalTaskType records for all journals...'
    Journal.all.each do |journal|
      JournalServices::CreateDefaultTaskTypes.call(journal)
    end

    Rails.logger.info 'Updating existing tasks title and old_role attributes...'
    all_registered_task_types = TaskType.types
    all_registered_task_types.each do |klass, defaults|
      klass.constantize.update_all old_role: defaults[:default_role],
                                   title: defaults[:default_title]
    end
  end

  desc "Destroy and recreate manuscript manager templates"
  task :reset_mmts => :environment do
    ManuscriptManagerTemplate.destroy_all
    Rake::Task["journal:create_default_templates"].invoke
  end

  task :copy_task_template_title => :environment do
    TaskTemplate.where(title: nil).find_each do |template|
      template.update_attribute(:title, template.journal_task_type.try(:title))
    end
  end

  task :initialize_initial_tech_check_round => :environment do
    PlosBioTechCheck::InitialTechCheckTask.update_all body: { round: 1 }
    puts 'All PlosBioTechCheck::InitialTechCheckTask body attributes have been initialized to {round: 1}'
  end
end
