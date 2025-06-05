window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.lowestProgress = {
  patch: function () {
    if (!ysy.settings.showLowestProgress) {
      ysy.pro.lowestProgress = null;
      return;
    }

    ysy.pro.lowestProgress = {
      name: "LowestProgressIssue",
      data: {},
      laggies: {},
      loaded: false,
      setting: null,
      className: " gantt-issue-lagging",
      patch: function () {
        var lowestClass = ysy.pro.lowestProgress;
        this.setting = new ysy.data.Data();
        this.setting.init({name: this.name, turnedOn: false});
        ysy.pro.toolPanel.registerButton({
          id: "show_lowest_progress_tasks",
          bind: function () {
            this.model = lowestClass.setting;
          },
          func: function () {
            this.model.turnedOn = !this.model.turnedOn;
            this.model._fireChanges(this, "click");
            if (this.model.turnedOn) {
              var send = lowestClass.load();
              if (!send) {
                lowestClass.colorizeLaggies();
              }
            } else {
              lowestClass.resetLaggies();
              lowestClass.decolorizeLaggies();
            }
          },
          isOn: function () {
            return this.model.turnedOn;
          }
        });
        gantt.templates.task_text = function (start, end, task) {
          if (!lowestClass.setting.turnedOn) return "";
          if (task.type === "project") {
            if (task.widget && task.widget.model) {
              var id = task.widget.model.id;
              var issuePack = lowestClass.data[id];
              if (issuePack) {
                return Mustache.render(
                    ysy.view.templates.lowestProgressText, issuePack
                ).replace(/,\s+#\$@&/, "");
              }
            }
          }
          return "";
        };
        ysy.data.loader.register(function () {
          if (!this.setting.turnedOn) return;
          if (!ysy.data.loader.loaded) {
            this.resetLaggies();
          }
          var send = this.load();
          if (!send) {
            this.colorizeLaggies();
          }
        }, this);
      },
      load: function () {
        var ids = [];
        var projects = ysy.data.projects.getArray();
        for (var i = 0; i < projects.length; i++) {
          var id = projects[i].id;
          if (this.data[id] === undefined) {
            ids.push(id);
          }
        }
        if (!ids.length) return false;
        ysy.gateway.polymorficPostJSON(
            ysy.settings.paths.lowestProgressTasks,
            {project_ids: ids},
            $.proxy(ysy.pro.lowestProgress._loadLaggies, this),
            ysy.pro.lowestProgress._handleError
        );
        return true;
      },
      _handleError: function (e) {
        console.error(e);
      },
      _loadLaggies: function (data) {
        if (!data || !data.easy_gantt_data) return;
        var issues = data.easy_gantt_data.issues;
        for (var i = 0; i < issues.length; i++) {
          var issue = issues[i];
          this.laggies[issue.id] = issue;
          var projectId = issue.project_id;
          if (!this.data[projectId]) {
            this.data[projectId] = {progress_date: issue.progress_date, issues: []};
          }
          this.data[projectId].issues.push(issue);
        }
        var projects = ysy.data.projects.getArray();
        for (i = 0; i < projects.length; i++) {
          projectId = projects[i].id;
          if (this.data[projectId] === undefined) {
            this.data[projectId] = false;
          }
        }
        this._redrawAllProjects("loaded");
        this.colorizeLaggies();
        this.loaded = true;
      },
      resetLaggies: function () {
        this.data = {};
        this.laggies = {};
        this.loaded = false;
        this._redrawAllProjects("reset");
      },
      _redrawAllProjects: function (reason) {
        var projects = ysy.data.projects.getArray();
        for (var i = 0; i < projects.length; i++) {
          projects[i]._fireChanges(this, reason);
        }
      },
      colorizeLaggies: function () {
        var issues = ysy.data.issues;
        for (var id in this.laggies) {
          if (!this.laggies.hasOwnProperty(id)) continue;
          var laggie = this.laggies[id];
          var issue = issues.getByID(laggie.id);
          if (!issue) continue;
          if (issue.css && issue.css.indexOf(this.className) > -1) continue;
          if (issue.css === undefined) issue.css = "";
          issue.css += this.className;
          issue._fireChanges(this, "colorizeLaggies");
        }
      },
      decolorizeLaggies: function () {
        var issues = ysy.data.issues.getArray();
        for (var i = 0; i < issues.length; i++) {
          var issue = issues[i];
          if (!issue.css || issue.css.indexOf(this.className) === -1) continue;
          issue.css = issue.css.replace(this.className, "");
          issue._fireChanges(this, "decolorizeLaggies");
        }
      }
    };
    ysy.pro.lowestProgress.patch();
  }
};