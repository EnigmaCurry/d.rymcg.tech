module EasyGantt
  module IssuePatch

    def self.prepended(base)
      base.include InstanceMethods

      base.class_eval do

        scope :gantt_opened, lambda {
          joins(:status).where(IssueStatus.table_name => { is_closed: false })
        }

      end
    end

    module InstanceMethods

      def gantt_editable?(user=nil)
        user ||= User.current

        (user.allowed_to?(:edit_easy_gantt, project) ||
         user.allowed_to_globally?(:edit_global_easy_gantt) ||
         (assigned_to_id == user.id &&
          user.allowed_to_globally?(:edit_personal_easy_gantt))) &&
        user.allowed_to?(:manage_issue_relations, project) &&
        user.allowed_to?(:edit_issues, project)
      end

      def gantt_latest_due
        if @gantt_latest_due.nil?
          dates = relations_from.map{|relation| relation.gantt_previous_latest_start }

          p = @parent_issue || parent
          if p && Setting.parent_issue_dates == 'derived'
            dates << p.gantt_latest_due
          end

          @gantt_latest_due = dates.compact.max
        end

        @gantt_latest_due
      end

    end

  end
end

Issue.prepend EasyGantt::IssuePatch

