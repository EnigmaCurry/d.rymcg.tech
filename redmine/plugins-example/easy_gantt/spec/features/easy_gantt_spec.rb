require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

RSpec.feature 'Easy gantt', js: true, logged: :admin do
  let!(:project) { FactoryGirl.create(:project, add_modules: ['easy_gantt']) }

  around(:each) do |example|
    with_settings(rest_api_enabled: 1) { example.run }
  end

  describe 'show gantt' do

    scenario 'show easy gantt on project' do
      visit easy_gantt_path(project)
      wait_for_ajax
      # unless Redmine::Plugin.installed?(:easy_gantt_pro)
      #   page.find('#sample_close_button').click
      #   wait_for_ajax
      # end
      expect(page).to have_css('#easy_gantt')
      expect(page.find('.gantt_grid_data')).to have_content(project.name)
      expect(page.find('#header')).to have_content(project.name)
    end

  end
end
