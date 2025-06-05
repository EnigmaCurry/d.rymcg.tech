window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.projectMove = {
  patch: function () {
    ysy.proManager.register("extendGanttTask", this.extendGanttTask);
    //var proManager = ysy.proManager;
    //var projectMoveClass = ysy.pro.projectMove;
    ysy.data.Project.prototype._shift = 0;
    gantt.attachEvent("onBeforeTaskOpened", function (id) {
      var task = gantt._pull[id];
      if (!task || !task.widget) return true;
      if (task.type !== "project") return true;
      var project = task.widget.model;
      if (project._shift) {
        dhtmlx.message(ysy.settings.labels.projectMove.error_opening_unsaved, "error");
        return false;
      }
      return true;
    });
    gantt.attachEvent("onTaskOpened", function (id) {
      var task = gantt._pull[id];
      if (!task || !task.widget) return true;
      if (task.type === "project") {
        task.editable = false;
      }
    });
    ysy.data.saver.sendProjects = function () {
      var j, data;
      if (!ysy.data.projects) return;
      var projects = ysy.data.projects.array;
      for (j = 0; j < projects.length; j++) {
        var project = projects[j];
        if (!project._changed) continue;
        //if (project._deleted && project._created) continue;
        data = {
          days: project._shift
          //project: {
          //}
        };
        ysy.gateway.sendProject("PUT", project, data, ysy.data.saver.callbackBuilder(project));
      }
    };
  },
  extendGanttTask: function (project, gantt_issue) {
    if (gantt_issue.type !== "project") return;
    if (project.needLoad || project.issues_count && !project.has_subprojects){
      gantt_issue.editable = true;
      gantt_issue.shift = project._shift * (60 * 60 * 24);
    }
  }
};
