class EasyBaselineGanttController < ApplicationController
  accept_api_auth :show

  before_action :find_baseline
  before_action :authorize

  def show
    # Wait for gantt modifications
    issue_ids = @project.issues.pluck(:id)
    version_ids = @project.versions.pluck(:id)

    b_table = EasyBaselineSource.table_name
    i_table = Issue.table_name
    v_table = Version.table_name

    @issues = @baseline.issues.
                        joins(:easy_baseline_source).
                        where(easy_baseline_sources: { source_id: issue_ids }).
                        pluck("#{i_table}.start_date, #{i_table}.due_date, #{i_table}.done_ratio, #{b_table}.source_id")

    @versions = @baseline.easy_baseline_sources.
                          versions.
                          joins_baseline_versions.
                          where(easy_baseline_sources: { source_id: version_ids }).
                          pluck("#{v_table}.effective_date, #{b_table}.source_id")

    respond_to do |format|
      format.api
    end
  end

  private

    def find_baseline
      @baseline = Project.includes(:easy_baseline_for).
                          where(id: params[:id]).
                          where.not(easy_baseline_for_id: nil).
                          first!
      @project = @baseline.easy_baseline_for
    rescue ActiveRecord::RecordNotFound
      render_404
    end

end
