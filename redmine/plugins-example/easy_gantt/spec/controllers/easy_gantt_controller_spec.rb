require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

RSpec.describe EasyGanttController, logged: :admin do

  around(:each) do |example|
    with_settings(rest_api_enabled: 1) { example.run }
  end

  context 'rest api' do
    let(:project) { FactoryGirl.create(:project, add_modules: ['easy_gantt']) }

    it 'disabled' do
      with_settings(rest_api_enabled: 0) do
        get :index, project_id: project
        expect(response).to be_error

        get :index
        expect(response).to be_error
      end
    end

    it 'enabled' do
      get :index
      expect(response).to be_success
    end
  end

end
