class CardContentAsNestedQuestionSerializer < AuthzSerializer
  root :nested_question
  attributes :id, :parent_id, :text, :ident, :value_type, :owner, :position

  has_many :repetitions, embed: :ids

  def owner
    { id: nil, type: object.card.name }
  end

  # Previously used for ordering. Now we just use lft
  def position
    object.lft
  end
end
