FactoryGirl.define do
  factory :nested_question_answer do
    nested_question
    sequence(:value) { |n| "value #{n}" }
    value_type "text"
  end
end