require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

RSpec.feature 'Global gantt', logged: :admin, js: true do
  let!(:superproject) {
    FactoryGirl.create(:project, add_modules: ['easy_gantt'], number_of_issues: 3)
  }
  around(:each) do |example|
    with_settings(rest_api_enabled: 1) { example.run }
  end
  unless Redmine::Plugin.installed?(:easy_gantt_pro) then
    it 'should load sample Data' do
      visit easy_gantt_path
      wait_for_ajax
      expect(page).to have_css('#sample_cont')
      expect(page).to have_text('1. Administrative Projects')
      expect(page).to have_text('2. HR Projects')
      expect(page).to have_text('3. IT Projects')
      expect(page).to have_text('4. Product Development')
    end
    it 'should open sample project' do
      visit easy_gantt_path
      wait_for_ajax
      expect(page).to have_text('3. IT Projects')
      page.find('[task_id="p3"] .gantt_open').click
      expect(page).to have_text('Client Project')
      expect(page).to have_text('Implementation of IS')
      expect(page).to have_text('Managing projects')
    end
  end
end