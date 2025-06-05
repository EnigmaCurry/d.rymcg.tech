module EasyGanttPro
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_easy_gantt_index_bottom, partial: 'hooks/easy_gantt_pro/view_easy_gantt_index_bottom'
    render_on :view_easy_gantts_issues_toolbars, partial: 'hooks/easy_gantt_pro/view_easy_gantts_issues_toolbars'
    render_on :view_easy_gantt_settings, partial: 'easy_settings/easy_gantt_pro'
  end
end
