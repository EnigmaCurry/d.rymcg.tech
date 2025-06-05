# Because of plugin deactivations
if Redmine::Plugin.installed?(:easy_gantt_pro)
  scope format: true, defaults: { format: 'json' }, constraints: { format: 'json' } do
    put 'easy_gantt/reschedule_project/:id', to: 'easy_gantt#reschedule_project', as: 'easy_gantt_reschedule_project'
    post 'easy_gantt/lowest_progress_tasks', to: 'easy_gantt_pro#lowest_progress_tasks', as: 'easy_gantt_lowest_progress_tasks'
  end

  scope 'easy_gantt', controller: 'easy_gantt_pro', as: 'easy_gantt' do
    get 'recalculate_fixed_delay'
  end
end
