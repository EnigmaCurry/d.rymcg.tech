Redmine::Plugin.register :easy_gantt do
  name 'Easy Gantt plugin'
  author 'Easy Software Ltd'
  url 'https://www.easysoftware.com'
  author_url 'https://www.easysoftware.com'
  description 'Cool gantt for redmine'
  version '3.0'

  requires_redmine version_or_higher: '6.0.0'

  settings partial: 'settings/easy_gantt', default: {
    'critical_path' => 'last',
    'default_zoom' => 'day',
    'show_project_progress' => '1',
    'show_lowest_progress_tasks' => '0',
    'show_task_soonest_start' => '0',
    'relation_delay_in_workdays' => '0'
  }
end

require_relative 'after_init'