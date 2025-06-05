class EasyGanttProController < EasyGanttController
  accept_api_auth :lowest_progress_tasks

  before_action :require_admin, only: [:recalculate_fixed_delay]

  # TODO: Calculate progress date on DB
  def lowest_progress_tasks
    project_ids = Array(params[:project_ids])

    @data = Hash.new { |hash, key| hash[key] = { date: Date.new(9999), ids: [] } }

    issues = Issue.open.joins(:status).
                   where(project_id: project_ids).
                   where.not(start_date: nil, due_date: nil).
                   pluck(:project_id, :id, :start_date, :due_date, :done_ratio)

    issues.each do |p_id, i_id, start_date, due_date, done_ratio|
      diff = due_date - start_date
      add_days = (diff * done_ratio.to_i) / 100
      progress_date = start_date + add_days.days

      project_data = @data[p_id]
      if project_data[:date] == progress_date
        project_data[:ids] << i_id
      elsif project_data[:date] > progress_date
        project_data[:date] = progress_date
        project_data[:ids] = [i_id]
      end
    end

    ids = @data.flat_map{|_, data| data[:ids]}
    @issues = Issue.select(:project_id, :id, :subject).where(id: ids)
  end

  def recalculate_fixed_delay
    statuses = [Project::STATUS_ACTIVE]

    issues = Issue.joins(:project).where(projects: { status: statuses })
    relations = IssueRelation.preload(:issue_from, :issue_to).
                              where(relation_type: IssueRelation::TYPE_PRECEDES).
                              where(issue_from_id: issues, issue_to_id: issues).
                              where.not(delay: nil)

    relations.each do |relation|
      next if relation.issue_from.nil? || relation.issue_to.nil?

      from = relation.issue_from.due_date || relation.issue_from.start_date
      to = relation.issue_to.start_date || relation.issue_to.due_date

      next if from.nil? || to.nil?

      saved_delay = relation.delay
      correct_delay = (to-from-1).to_i

      if saved_delay != correct_delay
        relation.update_column(:delay, correct_delay)
      end
    end

    flash[:notice] = l(:notice_easy_gantt_fixed_delay_recalculated)
    redirect_to :back
  end

end
