module EasyGantt
class EasyGanttProjectQuery < Query

  attr_accessor :opened_project

  self.queried_class = Project

  self.available_columns = [
    QueryColumn.new(:name, sortable: "#{Project.table_name}.name"),
    QueryColumn.new(:created_on, sortable: "#{Project.table_name}.created_on"),
    QueryColumn.new(:updated_on, sortable: "#{Project.table_name}.updated_on"),
  ]

  def initialize(*args)
    super
    self.filters ||= {}
  end

  def default_columns_names
    [:name]
  end

  def initialize_available_filters
    add_available_filter 'name', type: :text
    add_available_filter 'created_on', type: :date_past
    add_available_filter 'updated_on', type: :date_past
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

  def entities(options={})
    scope = Project.active.visible

    if Project.column_names.include?('easy_baseline_for_id')
      scope = scope.where(Project.table_name => { easy_baseline_for_id: nil })
    end

    scope = scope.includes(options[:includes]).
                  references(options[:includes]).
                  preload(options[:preload]).
                  where(statement).
                  where(options[:conditions]).
                  order(options[:order])

    if opened_project
      scope = scope(projects: { id: opened_project.id })
    end

    scope.to_a
  end

  def entity_scope
    Project.visible
  end

  def create_entity_scope(options={})
    entity_scope.includes(options[:includes]).
                 references(options[:includes]).
                 preload(options[:preload]).
                 where(statement).
                 where(options[:conditions])
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