window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.delayed_issues = {
  delayStates: null,
  patch: function () {

    ysy.pro.toolPanel.registerButton(
        {
          id: "delayed_issue_filter",
          bind: function () {
            this.model = ysy.data.limits;
          },
          func: function () {
            this.model.filter_delayed_issues = !this.model.filter_delayed_issues;
            ysy.pro.delayed_issues.updateRegistration(this.model.filter_delayed_issues);
            if (this.model.filter_delayed_issues) {
              ysy.pro.delayed_issues.decideDelayState();
            }
            this.model._fireChanges(this, "click");
          },
          isOn: function () {
            return this.model.filter_delayed_issues;
          },
          isHidden: function () {
            return ysy.settings.resource.open;
          }
        });
  },
  updateRegistration: function (isOn) {
    if (isOn) {
      ysy.proManager.register("filterTask", this.filterTask);
    } else {
      ysy.proManager.unregister("filterTask", this.filterTask);
    }
  },
  decideDelayState: function () {
    this.delayStates = {}; // true if delayed
    for (var id in gantt._pull) {
      if (!gantt._pull.hasOwnProperty(id)) continue;
      this.decideIfTaskDelayed(id);
    }
  },
  decideIfTaskDelayed: function (taskId) {
    if (this.delayStates[taskId] !== undefined) return this.delayStates[taskId];
    var task = gantt._pull[taskId];
    if (task.type === "task") {
      if (gantt._branches[task.id]) {
        var branch = gantt._branches[task.id];
        for (var i = 0; i < branch.length; i++) {
          var childId = branch[i];
          if (this.decideIfTaskDelayed(childId)) {
            return this.delayStates[task.id] = true;
          }
        }
        return this.delayStates[task.id] = false;
      } else {
        var diff = (moment() - task.start_date) / (86400000 + task.end_date - task.start_date);
        return this.delayStates[task.id] = task.progress !== 1 && task.progress < diff;
      }
    }
    return this.delayStates[task.id] = true;
  },
  filterTask: function (id, task) {
    return ysy.pro.delayed_issues.delayStates[id];
  }
};