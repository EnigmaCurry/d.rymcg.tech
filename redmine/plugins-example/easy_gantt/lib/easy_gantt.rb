module EasyGantt

    def self.non_working_week_days(user=nil)
      if user.is_a?(Integer)
        user = Principal.find_by(id: user)
      elsif user.nil?
        user = User.current
      end
  
      working_days = user.try(:current_working_time_calendar).try(:working_week_days)
      working_days = Array(working_days).map(&:to_i)
  
      if working_days.any?
        (1..7).to_a - working_days
      else
        Array(Setting.non_working_week_days).map(&:to_i)
      end
    end
  
    # Experimental function
    def self.load_fixed_delay?
      false
    end
    
    def self.easy_gantt_pro?
      Redmine::Plugin.installed?(:easy_gantt_pro)
    end
  
    def self.easy_baseline?
      Redmine::Plugin.installed?(:easy_baseline)
    end

end
  