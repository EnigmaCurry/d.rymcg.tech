require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

feature 'easy gantt', :js => true, :logged => :admin do
  let!(:project) { FactoryGirl.create(:project, add_modules: ['easy_gantt']) }
  describe 'show gantt' do
    around(:each) do |example|
      with_settings(rest_api_enabled: 1) do
        example.run
      end
    end

    scenario 'show global easy gantt' do
      visit easy_gantt_path
      wait_for_ajax
      expect(page).to have_css('#easy_gantt')
      expect(page.find('.gantt_grid_data')).to have_content(project.name)
    end

  end

end
