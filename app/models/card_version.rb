# CardVersion joins a Card to the different versions of its
# CardContent.  The card_versions table itself can also serve
# as a container for information we need to version that isn't
# card content
class CardVersion < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :card, inverse_of: :card_versions
  belongs_to :published_by, class_name: 'User'
  has_many :card_contents, inverse_of: :card_version, dependent: :destroy

  validates :card, presence: true
  validates :card_contents, presence: true
  # the `roots` scope comes from `awesome_nested_set`
  has_one :content_root, -> { roots }, class_name: 'CardContent'
  scope :required_for_submission, -> { where(required_for_submission: true) }
  scope :published, -> { where.not(published_at: nil) }

  validates :version, uniqueness: {
    scope: :card_id,
    message: "Card version numbers are unique for a given card"
  }

  validates :history_entry, presence: true, if: -> { published? }

  def published?
    published_at.present?
  end

  def publish!
    update!(published_at: Time.current)
  end

  def create_default_answers(task)
    card_contents.where.not(default_answer_value: nil).find_each do |content|
      task.answers.create!(
        card_content: content,
        paper: task.paper,
        value: content.default_answer_value
      )
    end
  end
end
