window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.ggrm = {
  _name: "GGRM",
  patch: function () {
    if (!ysy.pro.resource || !ysy.pro.resource.project_canvas_renderer) {
      ysy.pro.ggrm = null;
      return;
    }

    ysy.pro.ggrm = {
      patch: function () {
        ysy.proManager.register("close", this.close);
        var ggrmClass = ysy.pro.ggrm;
        ysy.view.AllButtons.prototype.extendees.ggrm = {
          bind: function () {
            this.model = ysy.settings.resource;
          },
          func: function () {
            var resource = ysy.settings.resource;
            if (resource.ggrm) {
              ggrmClass.close();
            } else {
              ggrmClass.open();
            }
          },
          isOn: function () {
            return ysy.settings.resource.ggrm;
          }
        };
        ysy.pro.resource.compileStyles();
        ysy.pro.sumRow.summers.ggrm = {
          day: function (date, project) {
            if (project.start_date.isAfter(date)) return 0;
            if (project.end_date.isBefore(date)) return 0;
            if (!project._ganttResources) return 0;
            var allocation = project._ganttResources[date.format("YYYY-MM-DD")];
            if (allocation > 0) return allocation;
            return 0;
          },
          week: function (first_date, last_date, project) {
            if (project.start_date.isAfter(last_date)) return 0;
            if (project.end_date.isBefore(first_date)) return 0;
            if (!project._ganttResources) return 0;
            var sum = 0;
            var mover = moment(first_date);
            while (mover.isBefore(last_date)) {
              var allocation = project._ganttResources[mover.format("YYYY-MM-DD")];
              if (allocation > 0) sum += allocation;
              mover.add(1, "day");
            }
            return sum;
          },
          entities: ["projects"],
          title: "GGRM"
        };
      },
      open: function () {
        var resource = ysy.settings.resource;
        if (resource.setSilent("ggrm", true)) {
          this.loadResources();
          ysy.settings.sumRow.setSummer("ggrm");
          ysy.view.bars.registerRenderer("project", this.outerRenderer);
          ysy.proManager.closeAll(this);
          resource._fireChanges(this, "toggle");
        }
      },
      close: function (except) {
        var resource = ysy.settings.resource;
        if (resource.setSilent("ggrm", false)) {
          ysy.settings.sumRow.removeSummer("ggrm");
          ysy.view.bars.removeRenderer("project", ysy.pro.ggrm.outerRenderer);
          resource._fireChanges(this, "toggle");
        }
      },
      loadResources: function (projectId) {
        var ids = [];
        var start_date;
        var end_date;
        var project;
        if (projectId) {
          ids.push(projectId);
          project = ysy.data.projects.getByID(projectId);
          start_date = project.start_date;
          end_date = project.end_date;
        } else {
          var projects = ysy.data.projects.getArray();
          for (var i = 0; i < projects.length; i++) {
            project = projects[i];
            ids.push(project.id);
            if (!start_date || project.start_date.isBefore(start_date)) {
              start_date = project.start_date;
            }
            if (!end_date || project.end_date.isAfter(end_date)) {
              end_date = project.end_date;
            }
          }
        }
        ysy.gateway.polymorficPostJSON(
            ysy.settings.paths.globalGanttResources
                .replace(":start", start_date.format("YYYY-MM-DD"))
                .replace(":end", end_date.format("YYYY-MM-DD")),
            {
              project_ids: ids
            },
            $.proxy(this._handleResourcesData, this),
            function () {
              ysy.log.error("Error: Unable to load data");
              //ysy.pro.resource.loader.loading = false;
            }
        );
      },
      _handleResourcesData: function (data) {
        var json = data.easy_resource_data;
        if (!json) return;
        this._resetProjects();
        this._loadProjects(json.projects);
      },
      _resetProjects: function () {
        var projects = ysy.data.projects.getArray();
        for (var i = 0; i < projects.length; i++) {
          delete projects[i]._ganttResources;
        }
      },
      _loadProjects: function (json) {
        var projects = ysy.data.projects;
        for (var i = 0; i < json.length; i++) {
          var project = projects.getByID(json[i].id);
          if (!project) continue;
          project._ganttResources = json[i].resources_sums;
          project._fireChanges(this, "load resources");
        }
      },
      outerRenderer: function (task, next) {
        var div = next().call(this, task, next);
        var allodiv = ysy.pro.ggrm._projectRenderer.call(gantt, task);
        div.appendChild(allodiv);
        return div;
      },
      _projectRenderer: function (task) {
        var resourceClass = ysy.pro.resource;
        var project = task.widget && task.widget.model;
        var allocPack = {allocations: project._ganttResources || {}, types: {}};
        var canvasList = ysy.view.bars.canvasListBuilder();
        canvasList.build(task, this);
        if (ysy.settings.zoom.zoom !== "day") {
          $.proxy(resourceClass.issue_week_renderer, this)(task, allocPack, canvasList);
        } else {
          $.proxy(resourceClass.issue_day_renderer, this)(task, allocPack, canvasList);
        }
        var element = canvasList.getElement();
        element.className += " project";
        return element;
      }
    };
    ysy.pro.ggrm.patch();
  }
};