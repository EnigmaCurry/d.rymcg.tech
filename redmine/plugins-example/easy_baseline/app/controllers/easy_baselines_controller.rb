class EasyBaselinesController < ApplicationController
  accept_api_auth :index, :create, :destroy

  before_action :find_project_by_project_id
  before_action :authorize
  before_action :authorize_baseline_source

  include Redmine::I18n
  include SortHelper

  def index
    @baselines = Project.where(easy_baseline_for: @project)
  end

  def new
    prepare_baseline
  end

  def create
    prepare_baseline

    Mailer.with_deliveries(false) do
      if @baseline.save(validate: false) && @baseline.copy(@project, only: ['versions', 'issues'], with_time_entries: false)
        # Easyredmine copies time on {copy_issues}
        @baseline.time_entries.destroy_all

        respond_to do |format|
          format.html {
            flash[:notice] = l(:notice_easy_baseline_created, project_name: @project.name)
            redirect_back_or_default project_easy_baselines_path(@project)
          }
          format.api  { render_api_ok }
        end
      else
        respond_to do |format|
          format.html { render :new }
          format.api  { render_validation_errors(@baseline) }
        end
      end
    end
  end

  def destroy
    @baseline = Project.find(params[:id])
    @baseline.destroy

    respond_to do |format|
      format.html {
        flash[:notice] = l(:notice_successful_delete)
        redirect_back_or_default project_easy_baselines_path(@project)
      }
      format.api { head :no_content }
    end
  end

  private

    def prepare_baseline(options={})
      options[:name] = params[:easy_baseline][:name] if params[:easy_baseline]

      @baseline = Project.copy_from(@project)
      @baseline.status = Project::STATUS_ARCHIVED
      # Without this hack it disables a modules on original project see http://www.redmine.org/issues/20512 for details
      @baseline.enabled_modules = []
      @baseline.enabled_module_names = @project.enabled_module_names
      @baseline.name =  options[:name] || (format_time(Time.now) + ' ' + @project.name)
      @baseline.identifier = options[:name].present? ? options[:name].parameterize : @project.identifier + '_' + Time.now.strftime('%Y%m%d%H%M%S')
      @baseline.easy_baseline_for_id = @project.id
      @baseline.parent = EasyBaseline.baseline_root_project
      # Project.copy_from change customized so CV are not copyied but moved
      # Already done in easyredmine
      @baseline.custom_values = @project.custom_values.map{|v| cloned_v = v.dup; cloned_v.customized = @baseline; cloned_v}
    end

    def authorize_baseline_source
      render_404 unless @project.easy_baseline_for.nil?
    end

end
