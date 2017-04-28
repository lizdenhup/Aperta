# Card is a container for CardContents
class Card < ActiveRecord::Base
  include EventStream::Notifiable
  include XmlSerializable

  acts_as_paranoid

  belongs_to :journal, inverse_of: :cards
  has_many :card_versions, inverse_of: :card, dependent: :destroy
  validates :name, presence: { message: "Please give your card a name." }
  # since we use acts_as_paranoid we need to take into account whether a card
  # has been deleted for uniqueness checks
  validates :name, uniqueness: {
    scope: [:journal, :deleted_at],
    message:  <<-MSG.strip_heredoc
      That card name is taken for this journal.
      Please give your card a new name.
    MSG
  }

  has_one :latest_card_version,
          ->(card) { where(version: card.latest_version) },
          class_name: 'CardVersion'

  # this method is used in the shim layer between nested questions
  # on the front end and card content on the backend.
  # in those cases, we don't need the proper tree of card content,
  # as the client is simply going to look up records by their ident
  # instead of traversing them.
  def content_for_version_without_root(version_no)
    content_for_version(version_no)
      .where.not(parent_id: nil)
  end

  # can take a version number or the symbol `:latest`
  def content_for_version(version_no)
    content_root_for_version(version_no).self_and_descendants
  end

  # can take a version number or the symbol `:latest`
  def content_root_for_version(version_no)
    card_version(version_no).content_root
  end

  # all the methods dealing with card content go through
  # `card_version`
  def card_version(version_no)
    to_find = if version_no == :latest
                latest_version
              else
                version_no
              end
    card_versions.find_by!(version: to_find)
  end

  def self.create_new!(attrs)
    Card.transaction do
      card = Card.new(attrs)
      card.card_versions << CardVersion.new(version: 1)
      card.card_versions.first.card_contents << CardContent.new(
        content_type: 'display-children'
      )
      card.save!
      card
    end
  end

  def to_xml(options = {})
    attrs = {
      'name' => name,
      'required-for-submission' =>
      latest_card_version.required_for_submission
    }
    setup_builder(options).card(attrs) do |xml|
      content_root_for_version(:latest).to_xml(
        builder: xml,
        skip_instruct: true
      )
    end
  end

  def xml=(xml)
    XmlCardLoader.version_from_xml_string(xml, self)
  end
end
