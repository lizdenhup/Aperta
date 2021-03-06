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

# rubocop:disable Metrics/MethodLength, Style/TrailingCommaInLiteral, Layout/SpaceInsideBrackets
module CustomCard
  class DefaultCardPermissions
    attr_reader :permissions

    def initialize(journal)
      @journal = journal
      @permissions = default_card_permissions
    end

    def validate(names)
      perms = @permissions.keys
      matching = names.sort == perms.sort
      raise StandardError, 'Mismatched custom card permissions' unless matching
    end

    def apply(key)
      permissions = @permissions[key]
      roles = get_roles(permissions)
      actions = get_actions(permissions)
      actions.each do |action|
        action_roles = roles_with_action(permissions, action)
        active_roles = roles.slice(*action_roles).values
        yield(action, active_roles)
      end
    end

    def match(name, permissions)
      apply(name) do |action, roles|
        yield(roles_with_action(permissions, action), roles.map(&:name))
      end
    end

    private

    def get_roles(permissions)
      roles = @journal.roles.where(name: permissions.keys).load
      roles.each_with_object({}) { |role, hash| hash[role.name] = role }
    end

    def get_actions(permissions)
      permissions.values.flatten.uniq
    end

    def roles_with_action(permissions, action)
      permissions.keys.select { |key| permissions[key].include?(action) }
    end

    def default_card_permissions
      {
        'additional_information'  => {
          'Academic Editor'       => ['view'],
          'Billing Staff'         => ['view', 'view_participants'],
          'Collaborator'          => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Cover Editor'          => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer'],
          'Creator'               => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Handling Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer'],
          'Internal Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Reviewer'              => ['view', 'view_participants'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer']
        },

        'competing_interests'     => {
          'Academic Editor'       => ['view'],
          'Billing Staff'         => ['view', 'view_participants'],
          'Collaborator'          => ['view', 'view_participants', 'manage_participant', 'edit'],
          'Cover Editor'          => ['view', 'view_participants', 'manage_participant', 'edit'],
          'Creator'               => ['view', 'view_participants', 'manage_participant', 'edit'],
          'Handling Editor'       => ['view', 'view_participants', 'manage_participant', 'edit'],
          'Internal Editor'       => ['view', 'view_participants', 'manage_participant', 'edit'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'manage_participant', 'edit'],
          'Publishing Services'   => ['view', 'view_participants', 'manage_participant', 'edit'],
          'Reviewer'              => ['view', 'view_participants'],
          'Staff Admin'           => ['view', 'view_participants', 'manage_participant', 'edit'],
        },

        'cover_letter'            => {
          'Academic Editor'       => ['view'],
          'Billing Staff'         => ['view', 'view_participants',                               'view_discussion_footer'],
          'Collaborator'          => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Cover Editor'          => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Creator'               => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Handling Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Internal Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Reviewer'              => ['view', 'view_participants'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer']
        },

        'data_availability'       => {
          'Academic Editor'       => ['view',                                                    'view_discussion_footer'],
          'Billing Staff'         => ['view', 'view_participants',                               'view_discussion_footer'],
          'Collaborator'          => ['view',                      'edit',                       'view_discussion_footer', 'edit_discussion_footer'],
          'Cover Editor'          => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Creator'               => ['view',                      'edit',                       'view_discussion_footer', 'edit_discussion_footer'],
          'Handling Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Internal Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Reviewer'              => ['view',                                                    'view_discussion_footer'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
        },

        'early_version'           => {
          'Academic Editor'       => ['view'],
          'Billing Staff'         => ['view', 'view_participants'],
          'Collaborator'          => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Cover Editor'          => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer'],
          'Creator'               => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Handling Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer'],
          'Internal Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Reviewer'              => ['view', 'view_participants'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
        },

        'ethics_statement'        => {
          'Academic Editor'       => ['view',                                                    'view_discussion_footer'],
          'Billing Staff'         => ['view', 'view_participants',                               'view_discussion_footer'],
          'Collaborator'          => ['view',                      'edit',                       'view_discussion_footer', 'edit_discussion_footer'],
          'Cover Editor'          => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Creator'               => ['view',                      'edit',                       'view_discussion_footer', 'edit_discussion_footer'],
          'Handling Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Internal Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Reviewer'              => ['view',                                                    'view_discussion_footer'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
        },

        'financial_disclosure'    => {
          'Academic Editor'       => ['view'],
          'Billing Staff'         => ['view', 'view_participants'],
          'Collaborator'          => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Cover Editor'          => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer'],
          'Creator'               => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Handling Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer'],
          'Internal Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Reviewer'              => ['view', 'view_participants'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
        },

        'preprint_decision'       => {
          'Billing Staff'         => [        'view_participants'],
          'Cover Editor'          => [        'view_participants',         'manage_participant', 'view_discussion_footer'],
          'Handling Editor'       => [        'view_participants',         'manage_participant', 'view_discussion_footer'],
          'Internal Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
        },

        'preprint_posting'        => {
          'Academic Editor'       => ['view'],
          'Billing Staff'         => ['view', 'view_participants'],
          'Collaborator'          => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Cover Editor'          => ['view', 'view_participants',         'manage_participant'],
          'Creator'               => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Handling Editor'       => ['view', 'view_participants',         'manage_participant'],
          'Internal Editor'       => ['view', 'view_participants',         'manage_participant'],
          'Journal Setup Admin'   => ['view'],
          'Participant'           => ['view', 'view_participants', 'edit'],
          'Production Staff'      => ['view', 'view_participants',         'manage_participant'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Reviewer'              => ['view', 'view_participants'],
          'Reviewer Report Owner' => ['view'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant'],
        },

        'reporting_guidelines'    => {
          'Academic Editor'       => ['view',                                                    'view_discussion_footer'],
          'Billing Staff'         => ['view', 'view_participants',                               'view_discussion_footer'],
          'Collaborator'          => ['view',                      'edit',                       'view_discussion_footer', 'edit_discussion_footer'],
          'Cover Editor'          => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Creator'               => ['view',                      'edit',                       'view_discussion_footer', 'edit_discussion_footer'],
          'Handling Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Internal Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Reviewer'              => ['view',                                                    'view_discussion_footer'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
        },

        'upload_manuscript'       => {
          'Academic Editor'       => ['view'],
          'Billing Staff'         => ['view', 'view_participants'],
          'Collaborator'          => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Cover Editor'          => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer'],
          'Creator'               => ['view', 'view_participants', 'edit', 'manage_participant'],
          'Handling Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer'],
          'Internal Editor'       => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Participant'           => ['view', 'view_participants'],
          'Production Staff'      => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Publishing Services'   => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
          'Reviewer'              => ['view', 'view_participants'],
          'Staff Admin'           => ['view', 'view_participants', 'edit', 'manage_participant', 'view_discussion_footer', 'edit_discussion_footer'],
        }
      }
    end
  end
end
