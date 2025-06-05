require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

RSpec.feature 'Critical', js: true, logged: :admin do

  let!(:project) { FactoryGirl.create(:project, add_modules: ['easy_gantt']) }
  #let!(:issue1) { FactoryGirl.create(:issue) }
  #let!(:issue2) { FactoryGirl.create(:issue) }
  #let!(:relation) { FactoryGirl.create(:issue_relation, source_id:issue1.id, target_id:issue2.id) }

  around(:each) do |example|
    with_settings(rest_api_enabled: 1) do
      with_easy_settings(easy_gantt_critical_path: 'last') do
        example.run
      end
    end
  end

  def open_critical_toolbar
    find('.easy-gantt__menu-tools').hover
    find('#button_critical').click
    find('#button_jump_today').hover
  end

  # TODO: '.gantt_task_line.gantt_task-type.critical' is empty
  #
  # it 'should test draw critical path' do
  #   # TODO: Remove this conditions
  #   skip if EasyGantt.platform == 'easyproject'
  #
  #   visit easy_gantt_path(project)
  #   wait_for_ajax
  #   within('#content') do
  #     open_critical_toolbar
  #     #click_link(l(:critical_path,:scope=>[:easy_gantt,:buttons]))
  #     expect(page).to have_css('#critical_show.active')
  #     expect(find('.gantt_task_line.gantt_task-type.critical')).to have_content(project.issues.first.subject)
  #   end
  # end

  it 'should open help' do
    # TODO: Remove this conditions
    skip if EasyGantt.platform == 'easyproject'

    visit easy_gantt_path(project)
    wait_for_ajax
    within('#content') do
      open_critical_toolbar
      find('#button_critical_help').click
    end
    expect(page).to have_css('#critical_help_modal_popup')
  end

end
