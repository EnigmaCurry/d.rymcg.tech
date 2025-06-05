window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.critical = {
  name: "CriticalPath",
  patch: function () {
    if(ysy.settings.criticalType === 'disabled') {
      ysy.pro.critical = null;
      return;
    }
    ysy.proManager.register("extendGanttTask", this.extendGanttTask);
    ysy.proManager.register("close", this.close);
    ysy.proManager.register("initToolbar", this.initToolbar);
    $.extend(ysy.view.AllButtons.prototype.extendees, {
      critical: {
        bind: function () {
          this.model = ysy.settings.critical;
          this._register(ysy.settings.resource);
        },
        func: function () {
          ysy.proManager.closeAll(ysy.pro.critical);
          var critical = ysy.settings.critical;
          critical.setSilent("open", !critical.open);
          ysy.pro.critical.toggle(critical.open);
          //critical._fireChanges(this, "toggle");
        },
        isOn: function () {
          return ysy.settings.critical.open
        },
        isHidden: function () {
          return ysy.settings.resource.open;
        }
      },
      show_only_critical: {
        bind: function () {
          this.model = ysy.settings.critical;
        },
        func: function () {
          this.model.show_only_critical = !this.model.show_only_critical;
          ysy.pro.critical.updateRegistration(this.model.show_only_critical);
          this.model._fireChanges(this, "click");
        },
        isOn: function () {
          return this.model.show_only_critical;
        }
      }
    });
  },
  byLongestPath: {
    critie_arr: null,
    crities: null,
    _construct: function () {
      var issues = ysy.data.issues.getArray();
      var relations = ysy.data.relations.getArray();
      var crities = {};
      var critie_arr = [];
      for (var i = 0; i < issues.length; i++) {
        var issue = issues[i];
        var critie = {
          issue: issue,
          duration: issue.getDuration("days"),
          source: [],
          target: [],
          longest: null
        };
        crities[issue.id] = critie;
        critie_arr.push(critie);
      }
      for (i = 0; i < relations.length; i++) {
        var relation = relations[i];
        if (relation.isSimple) continue;
        var source_critie = crities[relation.source_id];
        var target_critie = crities[relation.target_id];
        if (source_critie && target_critie) {
          source_critie.source.push(relation);
          target_critie.target.push(relation);
        } else {
          if (!source_critie) {
            ysy.log.debug("source_critie " + relation.source_id + " missing", "critical");
          }
          if (!target_critie) {
            ysy.log.debug("target_critie " + relation.target_id + " missing", "critical");
          }
        }
      }
      this.crities = crities;
      this.critie_arr = critie_arr;
      for (i = 0; i < critie_arr.length; i++) {
        critie = critie_arr[i];
        this._resolve(critie);
      }
      return this.crities;
    },
    _resolve: function (critie) {
      if (critie.longest !== null) return;
      var bestLongest = 0;
      for (var i = 0; i < critie.target.length; i++) { // iterate over relations which targets critie
        var relation = critie.target[i];
        var prevCritie = this.crities[relation.source_id];
        if (!prevCritie) {
          ysy.log.warning("nextCritie missing");
          continue;
        }
        this._resolve(prevCritie);
        var longest = prevCritie.longest
            + relation.delay
            - (relation.type === "start_to_finish" || relation.type === "finish_to_finish" ? critie.duration : 0)
            - (relation.type === "start_to_start" || relation.type === "start_to_finish" ? prevCritie.duration : 0);

        if (longest > bestLongest) {
          critie.prevMain = prevCritie;
          bestLongest = longest;
        }
      }
      critie.longest = bestLongest + critie.duration;
    },
    findPath: function () {
      if (!this.critie_arr) {
        this._construct();
      }
      var looser = null;
      var longest = 0;
      for (var i = 0; i < this.critie_arr.length; i++) {
        var critie = this.critie_arr[i];
        if (longest < critie.longest) {
          longest = critie.longest;
          looser = critie;
        }
      }
      var path = {};
      var last = null;
      if (looser) {
        while (looser.prevMain) {
          last = looser.issue.id;
          path[last] = true;
          looser = looser.prevMain;
        }
        last = looser.issue.id;
        path[last] = true;
        path["last"] = last;
      }
      this.reset();
      ysy.log.debug("findPath() path=" + JSON.stringify(path), "critical");
      return path;
      //this.path=path;
      //gantt.selectTask(path[path.length-1]);
    },
    reset: function () {
      this.critie_arr = null;
      this.crities = null;
      this.path = null;
    }
  },
  byLastIssue: {
    findPath: function () {
      var issues = ysy.data.issues.getArray();

      var lastIssues = [];
      var lastDate = null;
      for (var i = 0; i < issues.length; i++) {
        var issue = issues[i];
        if (!issue._end_date.isValid()) continue;
        if (lastDate !== null) {
          if (lastDate.isAfter(issue._end_date)) continue;
          if (lastDate.isBefore(issue._end_date)) {
            //lastDate = issue.end_date;
            lastIssues = [];
          }
        }
        lastDate = issue._end_date;
        lastIssues.push(issue);
      }
      if (lastIssues.length === 0) {
        return {};
      }
      var path = {};
      var soonestIssue = lastIssues[0];
      for (i = 0; i < lastIssues.length; i++) {
        issue = lastIssues[i];
        path[issue.id] = issue;
        if (soonestIssue._start_date.isAfter(issue._start_date)) {
          soonestIssue = issue;
        }
        var predecessor = this._resolve(issue, path);
        if (predecessor !== null && predecessor._start_date.isBefore(soonestIssue._start_date)) {
          soonestIssue = predecessor;
        }
      }
      path["last"] = soonestIssue.id;
      return path;
    },
    _resolve: function (issue, path) {
      var relations = ysy.data.relations.getArray();
      var soonestIssue = null;
      for (var i = 0; i < relations.length; i++) {
        var relation = relations[i];
        if (relation.isSimple) continue;
        if (relation.getTarget() !== issue) continue;
        //if (relation.type !== "precedes") continue;

        var diff = relation.getActDelay() - relation.delay;
        var source = relation.getSource();
        if (diff > 0) continue;
        // var gapStart = relation.getSourceDate(source);
        // var gapEnd = moment(gapStart).add(diff, "days");
        // gapEnd._isEndDate = gapStart._isEndDate;
        // if (gantt._working_time_helper.is_work_units_between(gapStart, gapEnd, "day")) continue;
        path[source.id] = source;
        if (soonestIssue === null || source._start_date.isBefore(soonestIssue._start_date)) {
          soonestIssue = source;
        }
        var predecessor = this._resolve(source, path);
        if (predecessor !== null
            && (soonestIssue === null
                || predecessor._start_date.isBefore(soonestIssue._start_date)
            )) {
          soonestIssue = predecessor;
        }
      }
      return soonestIssue;
    }

  },
  findPath: function () {
    if (ysy.settings.criticalType === "last") return this.byLastIssue.findPath();
    if (ysy.settings.criticalType === "longest") return this.byLongestPath.findPath();
    return {};
  },
  getPath: function () {
    var critical = ysy.settings.critical;
    if (critical.open === false) return null;
    if (critical.active === false) return null;
    var path;
    if (critical._cache) {
      return critical._cache;
    }
    path = ysy.pro.critical.findPath();
    critical._cache = path;
    if (critical._prevCache) {
      for (var key in critical._prevCache) {
        if (!critical._prevCache.hasOwnProperty(key)) continue;
        if (!path[key]) {
          gantt.refreshTask(key);
        }
      }
      for (key in path) {
        if (!path.hasOwnProperty(key)) continue;
        if (!critical._prevCache[key]) {
          gantt.refreshTask(key);
        }
      }
    }
    critical._prevCache = path;
    window.setTimeout(function () {
      critical._cache = null;
    }, 0);
    return path;
  },
  updateRegistration: function (isOn) {
    if (isOn) {
      ysy.proManager.register("filterTask", this.filterTask);
    } else {
      ysy.proManager.unregister("filterTask", this.filterTask);
    }
  }
  ,
  filterTask: function (id, task) {
    if (task.type === "task") {
      var path = ysy.pro.critical.getPath();
      return !!(path && path[task.real_id]);
    }
    return true;
  },
  toggle: function (state) {
    var critical = ysy.settings.critical;
    critical.setSilent("active", state === undefined ? !critical.active : state);
    if (critical.active) {
      var last = ysy.pro.critical.getPath()["last"];
      if (gantt.isTaskExists(last)) {
        gantt.selectTask(last);
      } else {
        gantt._selected_task = last;
      }
    }
    critical._fireChanges(this, "toggle");
  },
  close: function () {
    var sett = ysy.settings.critical;
    if (sett.setSilent("open", false)) {
      ysy.pro.critical.updateRegistration(false);
      sett._fireChanges(this, "close");
    }
  },
  initToolbar: function (ctx) {
    var criticalPanel = new ysy.view.CriticalPanel();
    criticalPanel.init(ysy.settings.critical);
    ctx.children.push(criticalPanel);
  },
  extendGanttTask: function (issue, gantt_issue) {
    var path = ysy.pro.critical.getPath();
    if (path && path[issue.id]) {
      gantt_issue.css += " critical";
    }
  }


};
//#############################################################################################
ysy.view = ysy.view || {};
ysy.view.CriticalPanel = function () {
  ysy.view.Widget.call(this);
};
ysy.main.extender(ysy.view.Widget, ysy.view.CriticalPanel, {
  name: "CriticalPanelWidget",
  templateName: "CriticalPanel",
  _repaintCore: function () {
    var sett = ysy.settings.critical;
    var target = this.$target;
    if (sett.open) {
      target.show();
    } else {
      target.hide();
    }
    if (sett.active) {
      target.find("#critical_show").addClass("active");
    } else {
      target.find("#critical_show").removeClass("active");
    }
    this.tideFunctionality();
  },
  tideFunctionality: function () {
    this.$target.find("#critical_show").off("click").on("click", function (event) {
      ysy.log.debug("Show Critical path button pressed", "critical");
      ysy.pro.critical.toggle();
    });
    this.$target.find("#button_critical_help").off("click").on("click", ysy.proManager.showHelp);
  }
});
