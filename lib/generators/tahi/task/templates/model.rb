module <%= @plugin.camelize %>
  class <%= class_name %>Task < Task
    # uncomment the following line if you want to enable event streaming for this model
    # include EventStreamNotifier

    register_task default_title: "<%= class_name %> Task", default_role: "author"

    def active_model_serializer
      <%= class_name %>TaskSerializer
    end
  end
end
