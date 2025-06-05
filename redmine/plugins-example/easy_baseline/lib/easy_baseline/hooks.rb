module EasyBaseline
  class Hooks < Redmine::Hook::ViewListener

    def model_project_copy_before_save(context={ })
      context[:destination_project].status = Project::STATUS_ARCHIVED if context[:destination_project].easy_baseline_for_id
    end

  end
end
