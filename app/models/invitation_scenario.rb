class InvitationScenario < TemplateContext
  subcontext :journal,                  source: [:object, :paper, :journal]
  subcontext :manuscript, type: :paper, source: [:object, :paper]
  subcontext :invitation,               source: :object
end
