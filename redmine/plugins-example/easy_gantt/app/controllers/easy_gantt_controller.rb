class EasyGanttController < ApplicationController
  accept_api_auth :index, :issues, :projects, :project_issues, :change_issue_relation_delay, :reschedule_project
  menu_item :easy_gantt

  RELATION_TYPES_TO_LOAD = ['relates', 'blocks', 'blocked', 'precedes', 'follows', 'start_to_start', 'finish_to_finish', 'start_to_finish']

  before_action :find_optional_project, except: [:reschedule_project, :project_issues]
  before_action :find_opened_project, except: [:reschedule_project]

  before_action :authorize, if: proc { @project.present? }
  before_action :authorize_global, if: proc { @project.nil? }

  before_action :check_rest_api_enabled, only: [:index]
  before_action :find_relation, only: [:change_issue_relation_delay]

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  helper :custom_fields
  helper :icons

  def index
    retrieve_query
  end

  # Data retrieve method
  def issues
    retrieve_query

    load_projects
    load_issues
    load_versions
    load_relations
    build_dates @issues, :start_date, :due_date
  end

  # Data retrieve method
  def projects
    retrieve_query

    load_projects
    build_dates @projects, :gantt_start_date, :gantt_due_date

    @projects_issues_counts = Issue.visible.gantt_opened.where(project_id: @projects).group(:project_id).count(:id)
  end

  def project_issues
    # TODO: Global route to skip rights
    @issues = Issue.visible.gantt_opened.where(project_id: params[:project_id]).order(:start_date)
    @issue_ids = @issues.map(&:id)
    load_relations

    version_ids = @issues.map(&:fixed_version_id).uniq.compact
    @versions = Version.open.where('id IN (?) OR project_id = ?', version_ids, params[:project_id]).sorted
  end

  def change_issue_relation_delay
    if !User.current.allowed_to?(:manage_issue_relations, @project)
      return render_403
    end

    @relation.update_column(:delay, params[:delay].to_i)

    respond_to do |format|
      format.api { render_api_ok }
    end
  end

  # You cannot use issue.reschedule_on because it will
  # also set start_date which is not desirable !!!
  def reschedule_project
    begin
      # Do not used callback `find_project` because it will test access rights
      # to project context. Method wont work if project does not have gantt enabled.
      project = Project.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
      return
    end

    project.gantt_reschedule(params[:days].to_i)

    respond_to do |format|
      format.api { render_api_ok }
    end
  end

  def current_menu_item
    @current_menu_item ||= if params[:gantt_type] == 'rm'
                             :resource
                           else
                             :easy_gantt
                           end
  end

  private

    def check_rest_api_enabled
      if Setting.rest_api_enabled != '1'
        render_error message: l('easy_gantt.errors.no_rest_api')
        return false
      end
    end

    def find_relation
      @relation = IssueRelation.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def query_class
      @project ? EasyGantt::EasyGanttIssueQuery : EasyGantt::EasyGanttProjectQuery
    end

    def retrieve_query
      if params[:query_id].present?
        cond = 'project_id IS NULL'

        if @project
          cond << " OR project_id = #{@project.id}"
        end

        @query = query_class.where(cond).find_by(id: params[:query_id])
        raise ActiveRecord::RecordNotFound if @query.nil?
        raise Unauthorized unless @query.visible?

        @query.project = @project
        sort_clear
      else
        @query = query_class.new(name: '_')
        @query.project = @project
        @query.from_params(params)
      end

      if @opened_project
        @query.opened_project = @opened_project
      end
    end

    # Load version from loaded task and from opened projects
    # TO_CONSIDER: Send versions if there is no tasks?
    def load_versions
      version_ids = @issues.map(&:fixed_version_id).uniq.compact
      @versions = Version.open.where("id IN (?) OR project_id = ?", version_ids, @opened_project.id).sorted
    end

    # Load subproject of opened project which contains filtered tasks
    #
    # Project 1
    # |-- Project 1.1
    # |   `-- Project 1.1.1
    # |       |-- Task 1
    # |       `-- Task 2
    # `-- Project 1.2
    #
    # If Project 1 is opened, Project 1.1 must be send even if there is no task
    #
    # TO_CONSIDER: Send full tree and load only opened_project's issues
    #
    def load_projects
      p_table = Project.table_name

      @projects = []

      # Project gantt is opened, normally only subprojects will be sent
      # but there is not any root project yet
      if @project && @opened_project == @project
        @projects << @project
      end

      projects = @query.without_opened_project { |q|
          scope = q.create_entity_scope

          # Not necessary, will take only subprojects
          if @opened_project
            scope = scope.where("#{p_table}.lft >= ? AND #{p_table}.rgt <= ?", @opened_project.lft, @opened_project.rgt)
          end

          scope.reorder(nil).distinct.pluck("#{p_table}.lft, #{p_table}.rgt, #{p_table}.parent_id")
        }

      if projects.blank?
        return
      end

      # All ancestors conditions
      tree_conditions = []
      projects.each do |lft, rgt|
        tree_conditions << "(lft <= #{lft} AND rgt >= #{rgt})"
      end
      tree_conditions = tree_conditions.join(' OR ')

      @parent_ids = projects.map(&:last)

      # From ancestors take only current opened level
      @projects.concat Project.where(tree_conditions).where(parent_id: @opened_project.try(:id)).to_a

      Project.load_gantt_dates(@projects)
      if Setting.plugin_easy_gantt['show_project_progress'] == '1'
        Project.load_gantt_completed_percent(@projects)
      end
    end

    # Only between loaded tasks
    def load_relations
      if @issue_ids.empty?
        @relations = []
      else
        @relations = IssueRelation.where('issue_from_id IN (?) OR issue_to_id IN (?)', @issue_ids, @issue_ids).
                                   where(relation_type: RELATION_TYPES_TO_LOAD)
      end
    end

    def load_issues
      preloads = [:project, :author, :assigned_to, :relations_to]

      if Setting.plugin_easy_gantt['show_task_soonest_start'] == '1'
        preloads << :parent
        preloads << { relations_to: :issue_from }
      else
        preloads << :relations_to
      end

      @issues = @query.entities(
          includes: [:project, :status, :assigned_to, :fixed_version, :tracker, :priority, :custom_values],
          preload: preloads,
          order: "#{Issue.table_name}.start_date, #{Issue.table_name}.id"
        )

      @issue_ids = @issues.map(&:id)
    end

    def build_dates(data, starts, ends)
      starts = data.map(&starts).compact
      ends = data.map(&ends).compact

      @start_date = (starts.min || ends.min || Date.today) - 1.day
      @end_date = (ends.max || starts.max || Date.today) + 1.day
    end

    def find_optional_project
      # Easy query workaround
      if params[:set_filter] == '1' && params[:project_id].present? && params[:project_id].start_with?('=', '!*', '*')
        return
      end

      super
    end

    def find_opened_project
      if params[:opened_project_id].present?
        @opened_project = Project.find(params[:opened_project_id])
      else
        @opened_project = @project
      end
    rescue ActiveRecord::RecordNotFound
      render_404
    end

end
