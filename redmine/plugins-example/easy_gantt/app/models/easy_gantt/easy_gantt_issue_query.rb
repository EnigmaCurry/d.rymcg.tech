module EasyGantt
  class EasyGanttIssueQuery < IssueQuery

    attr_accessor :entity_scope
    attr_accessor :opened_project

    def default_columns_names
      [:subject, :priority, :assigned_to]
    end

    def entity
      Issue
    end

    def from_params(params)
      build_from_params(params)
    end

    def to_params
      params = { set_filter: 1, type: self.class.name, f: [], op: {}, v: {} }

      filters.each do |filter_name, opts|
        params[:f] << filter_name
        params[:op][filter_name] = opts[:operator]
        params[:v][filter_name] = opts[:values]
      end

      params[:c] = column_names
      params
    end

    def to_partial_path
      'easy_gantt/easy_queries/show'
    end

    def initialize_available_filters
      super
      @available_filters.delete('subproject_id')
    end

    def entity_scope
      @entity_scope ||= begin
        scope = Issue.visible
        if Project.column_names.include? 'easy_baseline_for_id'
          scope = scope.where(Project.table_name => {easy_baseline_for_id: nil})
        end
        scope
      end
    end

    def create_entity_scope(options={})
      entity_scope.includes(options[:includes]).
                   references(options[:includes]).
                   preload(options[:preload]).
                   where(statement).
                   where(options[:conditions])
    end

    def entities(options={})
      create_entity_scope(options).order(options[:order])
    end

    def project_statement
      p_table = Project.table_name

      conditions = "#{p_table}.status = #{Project::STATUS_ACTIVE}"
      if opened_project
        conditions = "#{conditions} AND #{Project.table_name}.id = #{opened_project.id}"
      end
      conditions
    end

    def without_opened_project
      _opened_project = opened_project
      self.opened_project = nil
      yield self
    ensure
      self.opened_project = _opened_project
    end

  end
end
