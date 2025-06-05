module EasyGantt
  class Hooks < Redmine::Hook::ViewListener
    def helper_options_for_default_project_page(context={})
      context[:default_pages] << 'easy_gantt' if context[:enabled_modules].include?('easy_gantt')
    end
  end
end
