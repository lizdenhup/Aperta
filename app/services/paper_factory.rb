class PaperFactory
  attr_reader :paper, :author

  def self.create(paper_params, author)
    paper = author.submitted_papers.build(paper_params)
    pf = new(paper, author)
    pf.create
    pf.paper
  end

  def initialize(paper, author)
    @paper = paper
    @author = author
  end

  def apply_template
    template.phase_templates.each do |phase_template|
      phase = paper.phases.create!(name: phase_template['name'])

      phase_template.task_templates.each do |task_template|
        create_task(task_template, phase)
      end
    end
  end

  def create
    Paper.transaction do
      paper.build_default_author_groups
      paper.author_groups.first.authors << Author.new(to_author(author))
      add_collaborator(paper, author)
      if paper.valid?
        if template
          paper.save
          apply_template
        else
          paper.errors.add(:paper_type, "is not valid")
        end
      end
    end
  end

  def create_task(task_template, phase)
    task_klass = task_template.task_type.kind.constantize
    task = task_klass.new(
      phase: phase,
      title: task_template.title,
      body: task_template.template,
      role: task_template.journal_task_type.role
    )
    task.save!
    if task.role == 'author'
      task.participants << author
    end
  end

  def template
    @template ||= paper.journal.mmt_for_paper_type(paper.paper_type)
  end

  private

  def add_collaborator(paper, user)
    paper.paper_roles.build(user: user, role: PaperRole::COLLABORATOR)
  end

  def to_author(author)
    author.slice(*%w(first_name last_name email)).merge(position: 1)
  end
end
