module EasyGantt
  module ProjectPatch

    def self.prepended(base)
      base.extend ClassMethods
      base.include InstanceMethods
    end

    module InstanceMethods

      def gantt_editable?(user=nil)
        user ||= User.current

        (user.allowed_to?(:edit_easy_gantt, self) ||
         user.allowed_to_globally?(:edit_global_easy_gantt)) &&
        user.allowed_to?(:edit_project, self)
      end

      def gantt_reschedule(days)
        transaction do
          all_issues = Issue.joins(:project).where(gantt_subprojects_conditions)
          all_issues.update_all("start_date = start_date + INTERVAL '#{days}' DAY," +
                                "due_date = due_date + INTERVAL '#{days}' DAY")

          all_versions = Version.joins(:project).where(gantt_subprojects_conditions)
          all_versions.update_all("effective_date = effective_date + INTERVAL '#{days}' DAY")

          Redmine::Hook.call_hook(:model_project_gantt_reschedule, project: project, days: days, all_issues: all_issues)
        end
      end

      # Weighted completed percent including subprojects
      def gantt_completed_percent
        return @gantt_completed_percent if @gantt_completed_percent || @gantt_completed_percent_added

        i_table = Issue.table_name

        scope = Issue.where("#{i_table}.estimated_hours IS NOT NULL").
                      where("#{i_table}.estimated_hours > 0").
                      joins(:project).
                      where(gantt_subprojects_conditions)

        if scope.exists?
          sum = scope.select('(SUM(done_ratio / 100.0 * estimated_hours) / SUM(estimated_hours) * 100) AS sum_alias').reorder(nil).first
          @gantt_completed_percent = sum ? sum.sum_alias.to_f : 0.0
        else
          @gantt_completed_percent = 100.0
        end

        @gantt_completed_percent
      end

      def gantt_start_date
        return @gantt_start_date if @gantt_start_date || @gantt_start_date_added

        @gantt_start_date = [
          Issue.joins(:project).where(gantt_subprojects_conditions).minimum('start_date'),
          Version.joins(:project).where(gantt_subprojects_conditions).minimum('effective_date')
        ].compact.min
      end

      def gantt_due_date
        return @gantt_due_date if @gantt_due_date || @gantt_due_date_added

        @gantt_due_date = [
          Issue.joins(:project).where(gantt_subprojects_conditions).maximum('due_date'),
          Version.joins(:project).where(gantt_subprojects_conditions).maximum('effective_date')
        ].compact.max
      end

      def gantt_subprojects_conditions
        p_table = Project.table_name
        "#{p_table}.status <> #{Project::STATUS_ARCHIVED} AND #{p_table}.lft >= #{lft} AND #{p_table}.rgt <= #{rgt}"
      end

    end

    module ClassMethods

      def load_gantt_dates(projects)
        p_table = Project.table_name
        i_table = Issue.table_name
        v_table = Version.table_name

        project_ids = projects.map(&:id)

        data = []
        data.concat Project.where(id: project_ids).
                            joins("JOIN #{p_table} p2 ON p2.lft >= #{p_table}.lft AND p2.rgt <= #{p_table}.rgt").
                            joins("JOIN #{i_table} i ON i.project_id = p2.id").
                            where('p2.status <> ?', Project::STATUS_ARCHIVED).
                            group("#{p_table}.id").
                            pluck(Arel.sql("#{p_table}.id, MIN(i.start_date), MAX(i.due_date)"))

        data.concat Project.where(id: project_ids).
                            joins("JOIN #{p_table} p2 ON p2.lft >= #{p_table}.lft AND p2.rgt <= #{p_table}.rgt").
                            joins("JOIN #{v_table} v ON v.project_id = p2.id").
                            where('p2.status <> ?', Project::STATUS_ARCHIVED).
                            group("#{p_table}.id").
                            pluck(Arel.sql("#{p_table}.id, MIN(v.effective_date), MAX(v.effective_date)"))

        result = {}
        data.each do |id, min, max|
          if result.has_key?(id)
            result[id][0] = [result[id][0], min].compact.min
            result[id][1] = [result[id][1], max].compact.max
          else
            result[id] = [min, max]
          end
        end

        projects.each do |project|
          project_data = result[project.id]

          if project_data
            project.instance_variable_set :@gantt_start_date, project_data[0]
            project.instance_variable_set :@gantt_due_date, project_data[1]
          end

          project.instance_variable_set :@gantt_start_date_added, true
          project.instance_variable_set :@gantt_due_date_added, true
        end
      end

      def load_gantt_completed_percent(projects)
        p_table = Project.table_name
        i_table = Issue.table_name

        project_ids = projects.map(&:id)
        result = Project.where(id: project_ids).
                         joins("JOIN #{p_table} p2 ON p2.lft >= #{p_table}.lft AND p2.rgt <= #{p_table}.rgt").
                         joins("JOIN #{i_table} i ON i.project_id = p2.id").
                         where("i.estimated_hours IS NOT NULL AND i.estimated_hours > 0").
                         where("p2.status <> ?", Project::STATUS_ARCHIVED).
                         group("#{p_table}.id").
                         pluck(Arel.sql("#{p_table}.id, (SUM(i.done_ratio / 100.0 * i.estimated_hours) / SUM(i.estimated_hours) * 100)")).
                         to_h

        projects.each do |project|
          done_ratio = result[project.id]

          if done_ratio
            project.instance_variable_set :@gantt_completed_percent, done_ratio
          else
            project.instance_variable_set :@gantt_completed_percent, 100.0
          end

          project.instance_variable_set :@gantt_completed_percent_added, true
        end
      end

    end

  end
end

Project.prepend EasyGantt::ProjectPatch
