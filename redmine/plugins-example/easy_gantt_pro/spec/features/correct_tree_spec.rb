require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

RSpec.feature 'Correct tree', logged: :admin, js: true do

  let(:subproject) {
    FactoryGirl.create(:project, parent_id: superproject.id, add_modules: ['easy_gantt'], number_of_issues: 0)
  }
  let(:superproject) {
    FactoryGirl.create(:project, add_modules: ['easy_gantt'], number_of_issues: 0)
  }
  let(:superproject_issues) {
    FactoryGirl.create_list(:issue, 3, fixed_version_id: milestone_superproject.id, project_id: superproject.id)
  }
  let(:subproject_issues) {
    FactoryGirl.create_list(:issue, 3, fixed_version_id: milestone_subproject.id, project_id: subproject.id)
  }
  let(:milestone_subproject) {
    FactoryGirl.create(:version, project_id: subproject.id)
  }
  let(:milestone_superproject) {
    FactoryGirl.create(:version, project_id: superproject.id)
  }
  let(:subissues) {
    FactoryGirl.create_list(:issue, 3, parent_issue_id: superproject_issues[0].id, project_id: superproject.id)
  }

  around(:each) do |example|
    with_settings(rest_api_enabled: 1) { example.run }
  end

  it 'should show superproject items and hide subproject items and show them after open' do
    superproject_issues
    subproject_issues
    milestone_subproject
    visit easy_gantt_path(superproject)
    wait_for_ajax
    # superproject items are shown
    expect(page).to have_text(superproject.name)
    expect(page).to have_text(milestone_superproject.name)
    superproject_issues.each do |issue|
      expect(page).to have_text(issue.subject)
    end
    # subproject items are hidden
    expect(page).to have_text(subproject.name)
    expect(page).not_to have_text(milestone_subproject.name)
    subproject_issues.each do |issue|
      expect(page).not_to have_text(issue.subject)
    end
    # open subproject to show its items
    page.find("div[task_id='p#{subproject.id}'] .gantt_open").click
    wait_for_ajax
    expect(page).to have_text(milestone_subproject.name)
    subproject_issues.each do |issue|
      expect(page).to have_text(issue.subject)
    end
  end
end
