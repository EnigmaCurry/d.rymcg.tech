lib_dir = File.join(File.dirname(__FILE__), 'lib', 'easy_gantt_pro')

# Redmine patches
patch_path = File.join(lib_dir, '*_patch.rb')
Dir.glob(patch_path).each do |file|
  require file
end

require lib_dir
require File.join(lib_dir, 'hooks')

Redmine::MenuManager.map :easy_gantt_tools do |menu|
  menu.delete(:add_task)
  menu.delete(:critical)
  menu.delete(:baseline)

  menu.push(:baseline, 'javascript:void(0)',
    param: :project_id,
    caption: :'easy_gantt.button.create_baseline',
    icon: 'projects',
    html: { icon: 'icon-projects' },
    if: proc { |project|
      project.present? &&
      Redmine::Plugin.installed?(:easy_baseline) &&
      project.module_enabled?('easy_baselines') &&
      User.current.allowed_to?(:view_baselines, project)
    },
    after: :tool_panel)

  menu.push(:critical, 'javascript:void(0)',
    param: :project_id,
    caption: :'easy_gantt.button.critical_path',
    icon: 'summary',
    html: { icon: 'icon-summary' },
    if: proc { |p| p.present? && Setting.plugin_easy_gantt['critical_path'] != 'disabled' },
    after: :tool_panel)

  menu.push(:add_task, 'javascript:void(0)',
    param: :project_id,
    caption: :label_new,
    icon: 'add',
    html: { icon: 'icon-add' },
    if: proc { |project|
      project.present? &&
      User.current.allowed_to?(:edit_easy_gantt, project) &&
      (User.current.allowed_to?(:add_issues, project) ||
       User.current.allowed_to?(:manage_versions, project))
    },
    after: :tool_panel)

  menu.push(:delayed_project_filter, 'javascript:void(0)',
    caption: :'easy_gantt.button.delayed_project_filter',
    icon: 'list',
    html: { icon: 'icon-list' },
    if: proc {
      Setting.plugin_easy_gantt['show_project_progress'] == '1'
    })

  menu.push(:delayed_issue_filter, 'javascript:void(0)',
    caption: :'easy_gantt.button.delayed_issue_filter',
    icon: 'list',
    html: { icon: 'icon-list' })

  menu.push(:show_lowest_progress_tasks, 'javascript:void(0)',
    caption: :'easy_gantt.button.show_lowest_progress_tasks',
    icon: 'warning',
    html: { icon: 'icon-warning' },
    if: proc { |project|
      project.nil? && Setting.plugin_easy_gantt['show_lowest_progress_tasks'] == '1'
    })

end
