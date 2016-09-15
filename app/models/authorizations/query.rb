# Autoloader is not thread-safe in 4.x; it is fixed for Rails 5.
# Explicitly require any dependencies outside of app/. See a9a6cc for more info.
require_dependency 'emberize'

# rubocop:disable all
module Authorizations
  class Error < ::StandardError ; end
  class QueryError < Error ; end
  class CannotFindInverseAssociation < QueryError ; end

  # Query represents the quer(y|ies) for finding the authorized objects from
  # the database based on how the authorizations sub-system is configured,
  # what the user is assigned to, what roles the person has, and what
  # permissions they have thru those roles.
  class Query
    # WILDCARD represents the notion that any state is valid.
    WILDCARD = PermissionState::WILDCARD

    attr_reader :permission, :klass, :user

    # == Constructor Arguments
    # * permission - is the permission you are checking for authorization \
    #                against
    # * target - is the object, class, or ActiveRecord::Relation that is being \
    #            being authorized
    # * user - is the user who the query will be check for authorization against
    # * participations_only - a boolean specifying if only targets a user
    #                         participates in should be returned. If not
    #                         specified, it depends on the target passed in. For
    #                         Class or ActiveRecord::Relation, it is true, for
    #                         Array or ActiveRecord::Base, it is false.
    def initialize(permission:, target:, user:, participations_only: :default)
      @permission = permission.to_sym
      @user = user
      @target = target
      @participations_only = participations_only

      # we're looking for everything, e.g. Task got passed in
      if target.is_a?(Class)
        @klass = target
        @target = target.all
        @participations_only = true if @participations_only == :default

        # we're looking for a specific object, e.g. Task.first got passed in
      elsif target.is_a?(ActiveRecord::Base)
        @klass = target.class
        @target = @klass.where(id: target.id)
        @participations_only = false if @participations_only == :default

        # we're looking for a set of objects with a pre-existing query, e.g. Task.where(name: "Bar") got passed in
      elsif target.is_a?(ActiveRecord::Relation)
        @klass = target.model
        @participations_only = true if @participations_only == :default

        # we're looking for a specific of objects e.g. [Task.first, Task.last] got passed in
      elsif target.is_a?(Array)
        @klass = target.first.class
        @participations_only = false if @participations_only == :default
      end
    end

    def all
      if user.site_admin? && !@participations_only
        load_all_objects
      else
        load_authorized_objects
      end
    end

    private

    # +permission_state_column+ should return the column that houses
    # a model's state.
    #
    # This is so permissions that are tied to states can add a
    # WHERE condition in the query for matching against the right states.
    #
    # Right now this is set up to work for Paper(s). If the system needs to
    # evolve to work with other kinds of models this is the entry point for
    # refactoring, replacing, or removing.
    def permission_state_column
      :publishing_state
    end

    # +permission_state_join+ allows for a model to delegate their state
    # by implementing a `delegate_state_to` method on the class that
    # returns the name of the association to delegate to as a symbol.
    #
    # For example, having the following method in a model will delegate permission state to Paper:
    #  def self.delegate_state_to
    #    :paper
    #  end
    def permission_state_join
      @klass.try(:delegate_state_to)
    end

    def allowed?(object, states)
      states.include?(WILDCARD) ||
        !object.respond_to?(permission_state_column) ||
        states.member?(object.send(permission_state_column))
    end

    # +load_all_objects+ is a way to bypass R&P queries. It is intended to be
    # used in the case of Site Admins(s) or other System-level roles that
    # have access to everything in the system.
    #
    # Note: If :participations_only is true then this will never return any
    # records. This is because System accounts should _never_ be considered
    # participants.
    def load_all_objects
      result_set = ResultSet.new

      permission_names = Permission.where(applies_to: eligible_applies_to).pluck(:action)
      permission_hsh = {}
      permission_names.each do |name|
        permission_hsh[name.to_sym] = { states: ['*'] }
      end

      if @target.is_a?(Class)
        result_set.add_objects(@target.all, with_permissions: permission_hsh)
      elsif @target.is_a?(ActiveRecord::Base)
        result_set.add_objects([@target], with_permissions: permission_hsh)
      elsif @target.is_a?(ActiveRecord::Relation)
        result_set.add_objects(@target.all, with_permissions: permission_hsh)
      end

      result_set
    end

    # Returns the eligible values for a permission applies_to given the
    # @klass being queried. This searches the class, any of its descendants,
    # as well as any ancestors in the lineage from the @klass to its base-class.
    def eligible_applies_to
      eligible_ancestors = @klass.ancestors & @klass.base_class.descendants
      [
        @klass.descendants,
        @klass,
        eligible_ancestors,
        @klass.base_class
      ].flatten.map(&:name).uniq
    end

    def assignments_subquery
      assignments = Assignment.all
        .select('
          assignments.id,
          assignments.assigned_to_type,
          assignments.assigned_to_id,
          roles.id AS role_id,
          roles.name AS role_name,
          permissions.id AS permission_id'
        )
      .joins(permissions: :states)
      .where(assignments: { user_id: user.id })

     # explicitly add conditions rather than converting Assignment.all
     # to user.assignments. The reason is that ActiveRecord::Relation
     # will produce bind parameters that will not get handled correctly
     # when we convert to AREL queries below
     assignments_arel = assignments.arel

     # Find each authorization configured for the klass we're querying against
     auth_configs = Authorizations.configuration.authorizations.select do |ac|
       # if what we're authorizing is the same class or an ancestor of @klass
       ac.authorizes >= @klass
     end
     auth_configs.each do |ac|
       join_table = ac.assignment_to.arel_table
       source_table = ac.authorizes.arel_table
       inverse_of_via = ac.inverse_of_via
       association = ac.assignment_to.reflections[ac.via.to_s]

       assignments_arel.outer_join(join_table)
         .on(
       join_table[ ac.assignment_to.primary_key ]
         .eq( Assignment.arel_table[:assigned_to_id] )
         .and( Assignment.arel_table[:assigned_to_type]
         .eq(ac.assignment_to.name) ))
     end

     # add implicit JOIN in case the person is assigned directly to the
     # klass we're querying against
     assignments_arel.outer_join(@klass.arel_table)
       .on(
     @klass.arel_table[ @klass.primary_key ]
       .eq( Assignment.arel_table[:assigned_to_id] )
       .and( Assignment.arel_table[:assigned_to_type]
       .eq(@klass.name) ))

     klasses2where = auth_configs.map { |ac| ac.assignment_to } << @klass
     arel_conditions = klasses2where.reduce(nil) do |arel_conditions, klass|
       if arel_conditions
         arel_conditions.or(klass.arel_table.primary_key.not_eq(nil))
       else
         klass.arel_table.primary_key.not_eq(nil)
       end
     end

     assignments_arel.where(arel_conditions)
       .where(Permission.arel_table[:action].eq(@permission))
       .where(Permission.arel_table[:applies_to].in(eligible_applies_to))

     if @participations_only
       role_accessibility_method = "participates_in_#{@klass.table_name}"
       if Role.column_names.include?(role_accessibility_method)
         assignments_arel.where(Role.arel_table[role_accessibility_method.to_sym].eq(true))
       end
     end

     assignments_arel.group(Assignment.arel_table[:assigned_to_type])
       .group(Assignment.arel_table[:assigned_to_id])
       .group(Assignment.arel_table[:id])
       .group(Role.arel_table[:id])
       .group(Permission.arel_table[:id])

      assignments_arel
    end

    def objects_by_klass klass
      a2_table = Arel::Table.new(:assignments_table)
      composed_a2 = Arel::Nodes::As.new(assignments_table)
 
     # klass.arel_table.join(assignments_subquery).on(
     #   .project(Arel.sql('tasks.id as id, tasks.paper_id as paper_id, a2.role_id as role_id, a2.permission_id as permission_id'))
     #   .with(assignments_subquery)
     #   .where(
     # assignments_subquery.joins(Task.arel_table).on(Task.arel_table[:id].eq(assignments_subquery[:assigned_to_id]))
     #   .where(assignments_subquery[:assigned-to_type].eq('Task'))
    end

    def load_authorized_objects
      select_columns = 'tasks.id AS id, tasks.paper_id AS paper_id, a2_table.role_id AS role_id, a2_table.permission_id AS permission_id'
      a2_table = Arel::Table.new(:a2_table)
      composed_a2 = Arel::Nodes::As.new(a2_table, assignments_subquery)

      tasks = Task.arel_table
      tasks_query = tasks.join(a2_table).on(tasks[:id].eq(a2_table[:assigned_to_id]))
        .where(a2_table[:assigned_to_type].eq('Task'))
        .with(composed_a2)
        .project(Arel.sql(select_columns))

      papers = Paper.arel_table
      papers_query = papers.join(tasks, Arel::Nodes::OuterJoin).on(papers[:id].eq(tasks[:paper_id]))
        .join(a2_table, Arel::Nodes::OuterJoin).on(a2_table[:assigned_to_id].eq(papers[:id]))
        .where(a2_table[:assigned_to_type].eq('Paper')
        .project(Arel.sql(select_columns))

     # journals = Journal.arel_table
     # journals_query = journals.join(papers, Arel::Nodes::OuterJoin).on(papers[:journal_id].eq(journal[:id]))
      #  .join(papers[:journal_id].eq(journals[:id])

     # binding.pry
      perm_q = { 'permissions.applies_to' => eligible_applies_to, 'permissions.action' => @permission }
      assignments = user.assignments.includes(permissions: :states).where(perm_q)

      # If @participations_only is true then we want to use specific fields
      # on Role to determine if we should consider these assignments. The purpose of this
      # is so users assigned to a paper with a role like Author (or Reviewer, etc) get papers
      # through assignments in their default list of papers (e.g. what they see on the dashboard).
      # But we don't want that for roles (e.g. Internal Editor assigned to a Journal).
      if @participations_only
        role_accessibility_method = "participates_in_#{@klass.table_name}"
        if Role.column_names.include?(role_accessibility_method)
          assignments = assignments.where(:roles => { role_accessibility_method => true })
        end
      end

      # TODOMPM - this block of code should be taken care of by the above.  But verify that
      # Load all assignments the user has a permissible assignment for
      # if @permission == :*
      #  permissible_assignments = assignments.all
      #else
      #  permissible_assignments = assignments.where('permissions.action' => @permission)
      #end

      # Load all assignments (including permissions and permission states)
      # based on the permissible assignments, but DO NOT limit it to the
      # permissible action. We want to know all permissions this user has
      # for the assignment.
      # TODOMPM - Figure out how to do this later
      # permissions_by_assignment_id = assignments.where('assignments.id' => assignments.map(&:id)).reduce({}) do |h, assignment|
      #  h[assignment.id] = assignment.permissions
      #  h
      #end

      # Group by type so we can reduce queries later. 1 query for every combination of: kind of thing we're assigned to AND set of permissions.
      permissible_assignments_grouped = Hash.new{ |h,k| h[k] = [] }

      assignments.each do |assignment|
        permissions = assignment.permissions
        permissible_actions = permissions.flat_map(&:action).map(&:to_sym)
        permissible_state_names = permissions.flat_map(&:states).flat_map(&:name)
        #all_permissions = permissions_by_assignment_id[assignment.id].reduce({}) do |h, permission|
        #  h[permission.action.to_sym] = { states: permission.states.map(&:name).sort }
        #  h
        #end

        if permissible_actions.include?(@permission) || @permission == :*
            group_by_key = {
          type: assignment.assigned_to_type,
          permissible_states: permissible_state_names,
          all_permissions: {@permission => ['*']}
        }
        permissible_assignments_grouped[group_by_key] << assignment
        else
          # no-op: this assignment doesn't have a permission that allows authorization
        end
      end

      # Create a place to store the authorized objects
      result_set = ResultSet.new

      # Loop over the things we're assigned to and load them all up
      permissible_assignments_grouped.each_pair do |hsh, assignments|
        assigned_to_type = hsh[:type]
        permissible_states = hsh[:permissible_states]
        all_permissions = hsh[:all_permissions]

        assigned_to_klass = assigned_to_type.constantize
        authorized_objects = []

        # This is to make sure that if no permission states were hooked up
        # that we accept any state. It's more a fallback.
        permissible_states = [WILDCARD] if permissible_states.empty?

        # determine how this kind of thing relates to what we're interested in
        if assigned_to_klass <=> @klass
          authorized_objects = QueryAgainstAssignedObject.new(
            klass: @klass,
            target: @target,
            assignments: assignments,
            state_join: permission_state_join,
            permissible_states: permissible_states,
            state_column: permission_state_column
          ).query
          result_set.add_objects(authorized_objects, with_permissions: all_permissions)
        else
          # Determine how the Assignment#thing relates to object we're checking
          # permissions on. This can be pulled out later into a configurable property,
          # but for now just determined based on the reflection type that matches.
          Authorizations.configuration.authorizations
            .select { |auth|
            auth.authorizes >= @klass && # if what we're authorizing is the same class or an ancestor of @klass
              auth.assignment_to >= assigned_to_klass # if what you're assigned to is the same class
          }
            .each do |auth|
            authorized_objects = QueryAgainstAuthorization.new(
              authorization: auth,
              klass: @klass,
              target: @target,
              assigned_to_klass: assigned_to_klass,
              assignments: assignments,
              permissible_states: permissible_states,
              state_join: permission_state_join,
              state_column: permission_state_column
            ).query
            result_set.add_objects(authorized_objects, with_permissions: all_permissions)
          end
        end
      end

      result_set
    end

    class ResultSet
      def initialize
        @object_permission_map = Hash.new{ |h,k| h[k] = {} }
      end

      def add_objects(objects, with_permissions:)
        objects.each do |object|
          # Permission states may come thru multiple role assignments
          # so combine them together rather than overwrite. Otherwise
          # only the last set of permission sets seen will be kept in
          # this ResultSet
          @object_permission_map[object].merge!(with_permissions) do |key, v1, v2|
            { states: (v1[:states] + v2[:states]).uniq.sort }
          end
        end
      end

      def objects
        @object_permission_map.keys
      end

      delegate :each, :map, :length, to: :@object_permission_map

      def as_json
        serializable.as_json
      end

      def serializable
        results = []
        each do |object, permissions|
          item = PermissionResult.new(
            object: { id: object.id, type: object.class.sti_name },
            permissions: permissions,
            id: "#{Emberize.class_name(object.class)}+#{object.id}"
          )

          results.push item
        end
        results
      end
    end
  end
end

class PermissionResult
  attr_accessor :object, :permissions, :id
  include ActiveModel::SerializerSupport

  def initialize(object:, permissions:, id:)
    @object = object
    @permissions = permissions
    @id = id
  end
end
# rubocop:enable all
