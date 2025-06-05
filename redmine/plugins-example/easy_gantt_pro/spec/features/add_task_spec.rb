require File.expand_path('../../../../easyproject/easy_plugins/easy_extensions/test/spec/spec_helper', __FILE__)

RSpec.feature 'Add task', logged: :admin, js: true, js_wait: :long do
  let!(:project) { FactoryGirl.create(:project, add_modules: ['easy_gantt']) }

  around(:each) do |example|
    with_settings(rest_api_enabled: 1, text_formatting: 'textile') { example.run }
  end

  def open_add_toolbar
    find('.easy-gantt__menu-tools').hover
    click_link(I18n.t(:label_new))
    find('#button_jump_today').hover
  end

  describe 'toolbar' do

    it 'should prevent submitting invalid task' do
      # TODO: Remove this conditions
      skip if EasyGantt.platform == 'easyproject'

      visit easy_gantt_path(project)
      wait_for_ajax
      within('#content') do
        open_add_toolbar
        click_link(I18n.t(:label_issue_new))
      end
      wait_for_ajax
      find('#add_issue_modal_submit').click
      expect(page).to have_selector('.flash.error')
      expect(find('.flash.error')).to have_text(I18n.t(:field_subject))
    end

    it 'should create valid task' do
      # TODO: Remove this conditions
      skip if EasyGantt.platform == 'easyproject'

      visit easy_gantt_path(project)
      wait_for_ajax
      within('#content') do
        open_add_toolbar
        click_link(I18n.t(:label_issue_new))
      end
      wait_for_ajax
      within('#form-modal') do
        fill_in(I18n.t(:field_subject), with: 'Issue256')
      end
      find('#add_issue_modal_submit').click
      expect(page).to have_selector('.gantt_row.fresh.task-type', text: 'Issue256')
      accept_confirm { visit('about:blank') }
    end

    it 'should prevent submitting invalid milestone' do
      # TODO: Remove this conditions
      skip if EasyGantt.platform == 'easyproject'

      visit easy_gantt_path(project)
      wait_for_ajax
      within('#content') do
        open_add_toolbar
        click_link(I18n.t(:label_version_new))
        click_link(I18n.t(:label_version_new))
      end
      wait_for_ajax
      find('#add_milestone_modal_submit').click
      expect(page).to have_selector('.flash.error')
      expect(find('.flash.error')).to have_text(I18n.t(:field_name))
    end

    it 'should create valid milestone' do
      # TODO: Remove this conditions
      skip if EasyGantt.platform == 'easyproject'

      visit easy_gantt_path(project)
      wait_for_ajax
      within('#content') do
        open_add_toolbar
        click_link(I18n.t(:label_version_new))
        click_link(I18n.t(:label_version_new))
      end
      wait_for_ajax
      within('#form-modal') do
        fill_in(I18n.t(:field_name), with: 'Milestone256')
      end
      find('#add_milestone_modal_submit').click
      expect(page).to have_selector('.gantt_row.fresh.milestone-type', text: 'Milestone256')
      accept_confirm { visit('about:blank') }
    end

  end
end
