require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

RSpec.describe 'Permission', type: :request do

  let!(:user) { FactoryGirl.create(:user) }

  let!(:project1) { FactoryGirl.create(:project, number_of_issues: 3, add_modules: ['easy_gantt']) }
  let!(:project2) { FactoryGirl.create(:project, number_of_issues: 3, add_modules: ['easy_gantt']) }
  let!(:project3) { FactoryGirl.create(:project, number_of_issues: 3, add_modules: ['easy_gantt']) }

  let!(:role_nothing) { FactoryGirl.create(:role, permissions: []) }
  let!(:role_project_view) { FactoryGirl.create(:role, permissions: [:view_issues, :view_easy_gantt]) }
  let!(:role_project_edit) { FactoryGirl.create(:role, permissions: [:view_issues, :view_easy_gantt, :edit_easy_gantt, :manage_issue_relations, :edit_issues]) }

  let(:query) do
    _query = EasyIssueGanttQuery.new(name: '_')
    _query.filters = {}
    _query.add_filter('status_id', 'o', nil)
    _query
  end

  around(:each) do |example|
    with_settings(rest_api_enabled: 1) { example.run }
  end

  before(:each) do
    FactoryGirl.create(:member, project: project1, user: user, roles: [role_nothing])
    FactoryGirl.create(:member, project: project2, user: user, roles: [role_project_view])
    FactoryGirl.create(:member, project: project3, user: user, roles: [role_project_edit])

    logged_user(user)
  end

  # context 'Project level' do
  # end

  context 'Global level' do

    def get_issues(project)
      params = query.to_params.merge(opened_project_id: project.id, key: User.current.api_key, format: 'json')
      get projects_easy_gantt_path, params

      expect(response).to be_ok

      json = JSON.parse(body)
      json['easy_gantt_data']['issues']
    end

    # TODO: Global gantt now works with projects

    # it 'should see nothing' do
    #   binding.pry unless $__binding
    #   issues = get_issues(project1)
    #   expect(issues).to be_empty
    # end

    # it 'only view' do
    #   issues = get_issues(project2)
    #   expect(issues).to be_any
    #   expect(issues.map{|i| i['permissions']['editable']}).to all(be_nil)
    # end

    # it 'editable' do
    #   issues = get_issues(project3)
    #   expect(issues).to be_any
    #   expect(issues.map{|i| i['permissions']['editable']}).to all(be_truthy)
    # end

  end

end
