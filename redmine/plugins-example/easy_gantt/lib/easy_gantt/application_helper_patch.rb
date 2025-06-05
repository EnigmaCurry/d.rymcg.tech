module EasyGantt
  module ApplicationHelperPatch

    def self.prepended(base)
      base.class_eval do

        def link_to_project_with_easy_gantt(project, options = {})
          { controller: 'easy_gantt', action: 'index', project_id: project }
        end

      end
    end

  end
end

ApplicationHelper.prepend EasyGantt::ApplicationHelperPatch
