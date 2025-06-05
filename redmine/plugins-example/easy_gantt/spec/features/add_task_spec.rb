require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

RSpec.feature 'Add task', logged: :admin, js: true do
  let!(:project) { FactoryGirl.create(:project, add_modules: ['easy_gantt']) }

  around(:each) do |example|
    with_settings(rest_api_enabled: 1) { example.run }
  end

  describe 'toolbar' do

    unless Redmine::Plugin.installed?(:easy_gantt_pro)
      scenario 'should open help' do
        visit easy_gantt_path(project)
        wait_for_ajax
        page.find('.easy-gantt__menu-tools').hover
        expect(page).to have_selector('#button_add_task_help', text: I18n.t(:label_new))
        page.find('#button_add_task_help').click
        expect(page).to have_selector('#add_task_help_modal_popup')
      end
    end

  end
end
