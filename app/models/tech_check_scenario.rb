# Provides a template context for the Sendback Reasons Letter Template
class TechCheckScenario < TemplateContext
  subcontext  :journal,                        source: [:object, :paper, :journal]
  subcontext  :manuscript,       type: :paper, source: [:object, :paper]
  subcontext  :author,           type: :user,  source: [:object, :paper, :creator]
  subcontexts :sendback_reasons, type: :answer

  def intro
    task.answer_for('tech-check-email--email-intro').value
  end

  def footer
    task.answer_for('tech-check-email--email-footer').value
  end

  def sendback_reasons
    reasons = task.answers.select do |answer|
      content = CardContent.find answer.card_content_id
      parent = CardContent.find content.parent_id

      if (parent.content_type == 'sendback-reason') && (content.content_type == 'paragraph-input')
        targets = parent.children.to_ary
        # Dont check the display reason editor value. This should be replaced
        # once we have a tag system for better identifying answers
        targets.delete_at 1
        selection = targets.all? { |child| child.answers[0].try(:value) }
      else
        selection = false
      end
      selection
    end

    reasons.sort_by!(&:card_content_id)
    reasons.map { |reason| AnswerContext.new(reason) }
  end

  private

  def task
    object
  end
end