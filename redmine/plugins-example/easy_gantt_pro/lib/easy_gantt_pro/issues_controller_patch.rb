module EasyGanttPro
  module IssuesControllerPatch

    def self.prepended(base)
      base.include InstanceMethods

      base.class_eval do
        before_action :easy_gantt_suppress_notification
      end
    end

    module InstanceMethods

      private

      def easy_gantt_suppress_notification
        EasyGanttSuppressNotification.value = (params[:issue] && params[:issue][:easy_gantt_suppress_notification] == 'true')
      end

    end
  end
end
IssuesController.prepend EasyGanttPro::IssuesControllerPatch

