require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

RSpec.feature 'Gantt save', logged: :admin, js: true, slow: true do
  let(:subproject) {
    FactoryGirl.create(:project, :parent_id => superproject.id, add_modules: ['easy_gantt'], number_of_issues: 3)
  }
  let(:superproject) {
    FactoryGirl.create(:project, add_modules: ['easy_gantt'], number_of_issues: 3)
  }
  let(:superproject_milestone_issues) {
    FactoryGirl.create_list(:issue, 3, :fixed_version_id => superproject_milestone.id, :project_id => superproject.id)
  }
  let(:subproject_milestone_issues) {
    FactoryGirl.create_list(:issue, 3, :fixed_version_id => subproject_milestone.id, :project_id => subproject.id)
  }
  let(:subproject_milestone) {
    FactoryGirl.create(:version, project_id: subproject.id)
  }
  let(:superproject_milestone) {
    FactoryGirl.create(:version, project_id: superproject.id)
  }
  let(:subissues) {
    FactoryGirl.create_list(:issue, 3, :parent_issue_id => superproject.issues[0].id, :project_id => superproject.id)
  }

  around(:each) do |example|
    with_settings(rest_api_enabled: 1) { example.run }
  end


  it 'should save issue' do
    issue = superproject.issues[0]
    old_start_date = issue.start_date
    visit easy_gantt_path(superproject)
    wait_for_ajax
    expect(page).to have_text(issue.subject)
    move_script= <<-EOF
      (function(){var issue = ysy.data.issues.getByID(#{issue.id});
      issue.set({start_date:moment('#{Date.today + 2.days}'),end_date:moment('#{Date.today + 4.days}')});
      return "success";})()
    EOF
    save_button = page.find('#button_save')
    expect(page).to have_css('#button_save.disabled')
    expect(page.evaluate_script(move_script)).to eq('success')
    expect(page).not_to have_css('#button_save.disabled')
    save_button.click
    wait_for_ajax
    expect(page).to have_css('#button_save.disabled')
    issue.reload
    expect(issue.start_date).to eq(old_start_date + 2.days)
  end
end