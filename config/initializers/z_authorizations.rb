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

# This file must load after the devise initializer.
#
# This configuration defines how you get access to object based on your
# assignments.
#
# For example, if somebody is assigned to a Journal and they are trying to
# load the papers they have access to, this is used to tell the authorization
# subsystem that a user assigned to a Journal trying to access Paper will
# route thru the association called :papers on the Journal class.
#
# The only exception to this rule right are the System-level assignments.
# This is because the System-level assignment is only used for Site Admins (aka _superusers_).
# The authorization sub-system does not need to look up these routes for site admins
# even though the routes for them are supplied below.
#
Authorizations.configure do |config|
  #
  # Journal level access
  #
  config.assignment_to(
    Journal,
    authorizes: Paper,
    via: :papers
  )

  config.assignment_to(
    Journal,
    authorizes: Task,
    via: :tasks
  )

  config.assignment_to(
    Journal,
    authorizes: CardVersion,
    via: :card_versions
  )

  config.assignment_to(
    Journal,
    authorizes: Card,
    via: :cards
  )

  config.assignment_to(
    Journal,
    authorizes: DiscussionTopic,
    via: :discussion_topics
  )

  #
  # Paper level access
  #
  config.assignment_to(
    Paper,
    authorizes: Task,
    via: :tasks
  )

  config.assignment_to(
    Paper,
    authorizes: DiscussionTopic,
    via: :discussion_topics
  )

  config.assignment_to(
    Paper,
    authorizes: CardVersion,
    via: :card_versions
  )

  #
  # Task level access
  #
  config.assignment_to(
    Task,
    authorizes: Paper,
    via: :paper
  )

  config.assignment_to(
    Task,
    authorizes: CardVersion,
    via: :card_version
  )

  # When a permission with applies_to = Task also has a non-NULL
  # filter_by_card_id value, only apply that permission to tasks that belong to
  # a card_version that has the same card_id.
  config.filter(Task, :filter_by_card_id) do |query, column, table|
    # Use an alias because we may be joining against this table elsewhere in the
    # query.
    card_versions = CardVersion.arel_table.alias
    # When APERTA-9889 is merged, may no longer be necessary to do an outer
    # join, since all card_version_ids should be set.
    query.join(card_versions, Arel::Nodes::OuterJoin)
      .on(card_versions[:id].eq(table[:card_version_id]))
      .where(column.eq(nil).or(column.eq(card_versions[:card_id])))
  end

  # TODO: APERTA-10226
  # This code was generating a SQL error. To be fixed in APERTA-10226.
  # config.filter(CardVersion, :filter_by_card_id) do |query, column, table|
  #   query.where(table[:card_id].eq(column).or(column.eq(nil)))
  # end
end
