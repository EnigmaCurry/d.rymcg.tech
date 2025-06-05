# Because of plugin deactivations
if Redmine::Plugin.installed?(:easy_gantt)
  get '(projects/:project_id)/easy_gantt' => 'easy_gantt#index', as: 'easy_gantt'

  scope format: true, defaults: { format: 'json' }, constraints: { format: 'json' } do
    scope 'projects/:project_id' do
      get 'easy_gantt/issues' => 'easy_gantt#issues', as: 'issues_easy_gantt'
      put 'easy_gantt/relation/:id' => 'easy_gantt#change_issue_relation_delay', as: 'relation_easy_gantt'
      get 'easy_gantt/project_issues' => 'easy_gantt#project_issues', as: 'project_issues_easy_gantt'
    end
    get 'easy_gantt/projects' => 'easy_gantt#projects', as: 'projects_easy_gantt'
  end
end
